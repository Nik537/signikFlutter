"""API route handlers for Signik Broker."""
import uuid
import base64
from datetime import datetime
from typing import Optional
from fastapi import HTTPException, WebSocket, WebSocketDisconnect
import json
import logging

from models import (
    Device, Document, DeviceConnection, DeviceType, DocStatus, ConnectionStatus,
    RegisterDeviceRequest, RegisterDeviceResponse, EnqueueDocRequest, EnqueueDocResponse,
    ConnectDeviceRequest, UpdateConnectionRequest, DeviceListResponse, 
    DocumentListResponse, ConnectionListResponse, SignikMessage
)
from storage import StorageManager
from websocket_manager import WebSocketManager

logger = logging.getLogger(__name__)


class APIRoutes:
    """Handles all API route logic."""
    
    def __init__(self, storage: StorageManager, ws_manager: WebSocketManager):
        self.storage = storage
        self.ws_manager = ws_manager
    
    async def register_device(self, request: RegisterDeviceRequest) -> RegisterDeviceResponse:
        """Register a new device or update existing one."""
        # Check for existing device (deduplication)
        existing_device = await self.storage.find_device_by_name_and_type(
            request.device_name, 
            request.device_type
        )
        
        if existing_device:
            # Update existing device
            existing_device.ip_address = request.ip_address
            existing_device.last_heartbeat = datetime.now()
            existing_device.is_online = True
            await self.storage.add_device(existing_device)
            
            logger.info(f"Updated existing device: {existing_device.name} ({existing_device.id})")
            return RegisterDeviceResponse(
                device_id=existing_device.id,
                message="Device updated successfully",
                is_update=True
            )
        
        # Create new device
        device_id = str(uuid.uuid4())
        device = Device(
            id=device_id,
            name=request.device_name,
            device_type=request.device_type,
            ip_address=request.ip_address,
            last_heartbeat=datetime.now()
        )
        await self.storage.add_device(device)
        
        logger.info(f"Registered new device: {device.name} ({device.id})")
        return RegisterDeviceResponse(
            device_id=device_id,
            message="Device registered successfully",
            is_update=False
        )
    
    async def enqueue_document(self, request: EnqueueDocRequest) -> EnqueueDocResponse:
        """Add a document to the signing queue."""
        # Validate Windows device exists
        windows_device = await self.storage.get_device(request.windows_device_id)
        if not windows_device:
            raise HTTPException(status_code=404, detail="Windows device not found")
        
        if windows_device.device_type != DeviceType.WINDOWS:
            raise HTTPException(status_code=400, detail="Device must be a Windows device")
        
        # Convert base64 to bytes if provided
        pdf_data = None
        if request.pdf_data:
            try:
                pdf_data = base64.b64decode(request.pdf_data)
            except Exception as e:
                logger.error(f"Failed to decode PDF data: {e}")
                raise HTTPException(status_code=400, detail="Invalid PDF data encoding")
        
        # Create document
        doc_id = str(uuid.uuid4())
        document = Document(
            id=doc_id,
            name=request.name,
            status=DocStatus.QUEUED,
            created_at=datetime.now(),
            updated_at=datetime.now(),
            windows_device_id=request.windows_device_id,
            pdf_data=pdf_data
        )
        await self.storage.add_document(document)
        
        logger.info(f"Document '{request.name}' enqueued with ID: {doc_id}")
        return EnqueueDocResponse(
            doc_id=doc_id,
            message="Document enqueued successfully"
        )
    
    async def get_devices(self, device_type: Optional[DeviceType] = None) -> DeviceListResponse:
        """Get all registered devices."""
        devices = await self.storage.get_all_devices(device_type=device_type)
        return DeviceListResponse(
            devices=[d.dict() for d in devices],
            total=len(devices)
        )
    
    async def get_online_devices(self, device_type: Optional[DeviceType] = None) -> DeviceListResponse:
        """Get only online devices."""
        devices = await self.storage.get_all_devices(
            device_type=device_type,
            online_only=True
        )
        return DeviceListResponse(
            devices=[d.dict() for d in devices],
            total=len(devices)
        )
    
    async def get_documents(self, status: Optional[DocStatus] = None) -> DocumentListResponse:
        """Get all documents."""
        documents = await self.storage.get_all_documents(status=status)
        # Exclude binary data from response
        docs_data = []
        for doc in documents:
            doc_dict = doc.dict()
            doc_dict.pop('pdf_data', None)
            doc_dict.pop('signature_data', None)
            docs_data.append(doc_dict)
        
        return DocumentListResponse(
            documents=docs_data,
            total=len(documents)
        )
    
    async def heartbeat(self, device_id: str) -> dict:
        """Process device heartbeat."""
        success = await self.storage.update_device_heartbeat(device_id)
        if not success:
            raise HTTPException(status_code=404, detail="Device not found")
        
        return {"message": "Heartbeat received"}
    
    async def connect_device(self, device_id: str, request: ConnectDeviceRequest) -> dict:
        """Initiate a connection between two devices."""
        # Validate source device
        source_device = await self.storage.get_device(device_id)
        if not source_device:
            raise HTTPException(status_code=404, detail="Source device not found")
        
        # Validate target device
        target_device = await self.storage.get_device(request.target_device_id)
        if not target_device:
            raise HTTPException(status_code=404, detail="Target device not found")
        
        # Ensure devices are of different types
        if source_device.device_type == target_device.device_type:
            raise HTTPException(
                status_code=400, 
                detail="Cannot connect devices of the same type"
            )
        
        # Check if connection already exists
        if await self.storage.connection_exists(device_id, request.target_device_id):
            raise HTTPException(status_code=400, detail="Connection already exists")
        
        # Create connection
        connection_id = str(uuid.uuid4())
        windows_id = (device_id if source_device.device_type == DeviceType.WINDOWS 
                     else request.target_device_id)
        android_id = (request.target_device_id if target_device.device_type == DeviceType.ANDROID 
                     else device_id)
        
        connection = DeviceConnection(
            id=connection_id,
            windows_device_id=windows_id,
            android_device_id=android_id,
            status=ConnectionStatus.PENDING,
            created_at=datetime.now(),
            updated_at=datetime.now(),
            initiated_by=device_id
        )
        await self.storage.add_connection(connection)
        
        # Notify target device about connection request
        message = {
            "type": "connectionRequest",
            "connection_id": connection_id,
            "from_device": source_device.dict()
        }
        await self.ws_manager.send_to_device(request.target_device_id, message)
        
        logger.info(f"Connection request from {source_device.name} to {target_device.name}")
        return {"connection_id": connection_id, "message": "Connection request sent"}
    
    async def get_device_connections(self, device_id: str) -> dict:
        """Get all connections for a specific device."""
        device = await self.storage.get_device(device_id)
        if not device:
            raise HTTPException(status_code=404, detail="Device not found")
        
        connections = await self.storage.get_device_connections(device_id)
        
        # Enrich with device information
        connections_data = []
        for conn in connections:
            other_device_id = (conn.android_device_id if conn.windows_device_id == device_id 
                             else conn.windows_device_id)
            other_device = await self.storage.get_device(other_device_id)
            
            conn_data = conn.dict()
            conn_data["other_device"] = other_device.dict() if other_device else None
            connections_data.append(conn_data)
        
        return {"connections": connections_data}
    
    async def update_connection(self, connection_id: str, request: UpdateConnectionRequest) -> dict:
        """Update connection status."""
        connection = await self.storage.get_connection(connection_id)
        if not connection:
            raise HTTPException(status_code=404, detail="Connection not found")
        
        # Update status
        success = await self.storage.update_connection_status(connection_id, request.status)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to update connection")
        
        # Notify both devices
        message = {
            "type": "connectionStatusUpdate",
            "connection_id": connection_id,
            "status": request.status.value
        }
        
        await self.ws_manager.broadcast_to_devices(
            [connection.windows_device_id, connection.android_device_id],
            message
        )
        
        logger.info(f"Connection {connection_id} status updated to {request.status.value}")
        return {"message": f"Connection status updated to {request.status.value}"}
    
    async def get_all_connections(self, status: Optional[ConnectionStatus] = None) -> ConnectionListResponse:
        """Get all device connections."""
        connections = await self.storage.get_all_connections(status=status)
        
        # Enrich with device information
        connections_data = []
        for conn in connections:
            windows_device = await self.storage.get_device(conn.windows_device_id)
            android_device = await self.storage.get_device(conn.android_device_id)
            
            conn_data = conn.dict()
            conn_data["windows_device"] = windows_device.dict() if windows_device else None
            conn_data["android_device"] = android_device.dict() if android_device else None
            connections_data.append(conn_data)
        
        return ConnectionListResponse(
            connections=connections_data,
            total=len(connections)
        )
    
    async def delete_connection(self, connection_id: str) -> dict:
        """Remove a device connection."""
        connection = await self.storage.get_connection(connection_id)
        if not connection:
            raise HTTPException(status_code=404, detail="Connection not found")
        
        # Notify both devices
        message = {
            "type": "connectionRemoved",
            "connection_id": connection_id
        }
        
        await self.ws_manager.broadcast_to_devices(
            [connection.windows_device_id, connection.android_device_id],
            message
        )
        
        # Delete connection
        success = await self.storage.delete_connection(connection_id)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to delete connection")
        
        logger.info(f"Connection {connection_id} removed")
        return {"message": "Connection removed successfully"}
    
    async def handle_websocket(self, websocket: WebSocket, device_id: str) -> None:
        """Handle WebSocket connection for a device."""
        # Connect
        if not await self.ws_manager.connect(device_id, websocket):
            return
        
        # Update device status
        await self.storage.update_device_status(device_id, True)
        
        try:
            while True:
                # Receive message (text or binary)
                message_data = await websocket.receive()
                
                if "text" in message_data:
                    # Handle JSON message
                    try:
                        message = SignikMessage.parse_raw(message_data["text"])
                        message.sender_device_id = device_id
                        await self.ws_manager.route_message(message, websocket)
                    except Exception as e:
                        logger.error(f"Error parsing message from {device_id}: {e}")
                
                elif "bytes" in message_data:
                    # Handle binary data
                    await self.ws_manager.route_binary_data(message_data["bytes"], device_id)
        
        except WebSocketDisconnect:
            logger.info(f"Device {device_id} disconnected")
        except Exception as e:
            logger.error(f"WebSocket error for device {device_id}: {e}")
        finally:
            # Cleanup
            self.ws_manager.disconnect(device_id)
            await self.storage.update_device_status(device_id, False)