"""WebSocket connection and message routing manager."""
from typing import Dict, Optional
from fastapi import WebSocket
import json
import logging
from datetime import datetime

from models import SignikMessage, DocStatus, DeviceType
from storage import StorageManager

logger = logging.getLogger(__name__)


class WebSocketManager:
    """Manages WebSocket connections and message routing."""
    
    def __init__(self, storage: StorageManager):
        self.connections: Dict[str, WebSocket] = {}
        self.storage = storage
        self.last_target_device: Optional[str] = None
    
    async def connect(self, device_id: str, websocket: WebSocket) -> bool:
        """Connect a device WebSocket."""
        device = await self.storage.get_device(device_id)
        if not device:
            await websocket.close(code=1008, reason="Device not registered")
            return False
        
        await websocket.accept()
        self.connections[device_id] = websocket
        logger.info(f"Device {device.name} ({device_id}) connected via WebSocket")
        return True
    
    def disconnect(self, device_id: str) -> None:
        """Disconnect a device WebSocket."""
        if device_id in self.connections:
            del self.connections[device_id]
            logger.info(f"Device {device_id} disconnected from WebSocket")
    
    async def send_to_device(self, device_id: str, message: dict) -> bool:
        """Send a JSON message to a specific device."""
        if device_id not in self.connections:
            logger.warning(f"Cannot send message to {device_id} - not connected")
            return False
        
        try:
            await self.connections[device_id].send_text(json.dumps(message))
            return True
        except Exception as e:
            logger.error(f"Error sending message to {device_id}: {e}")
            self.disconnect(device_id)
            return False
    
    async def send_bytes_to_device(self, device_id: str, data: bytes) -> bool:
        """Send binary data to a specific device."""
        if device_id not in self.connections:
            logger.warning(f"Cannot send binary data to {device_id} - not connected")
            return False
        
        try:
            await self.connections[device_id].send_bytes(data)
            return True
        except Exception as e:
            logger.error(f"Error sending binary data to {device_id}: {e}")
            self.disconnect(device_id)
            return False
    
    async def broadcast_to_devices(self, device_ids: list[str], message: dict) -> None:
        """Broadcast a message to multiple devices."""
        for device_id in device_ids:
            await self.send_to_device(device_id, message)
    
    async def route_binary_data(self, binary_data: bytes, sender_device_id: str) -> bool:
        """Route binary PDF data to the appropriate device."""
        logger.info(f"Routing {len(binary_data)} bytes from {sender_device_id}")
        
        # Use last target device if available
        if self.last_target_device and self.last_target_device in self.connections:
            device = await self.storage.get_device(self.last_target_device)
            if device and device.is_online:
                success = await self.send_bytes_to_device(self.last_target_device, binary_data)
                if success:
                    logger.info(f"Binary data sent to target device {device.name}")
                    return True
        
        # Fallback: send to first available Android device
        android_devices = await self.storage.get_all_devices(
            device_type=DeviceType.ANDROID, 
            online_only=True
        )
        
        for device in android_devices:
            if device.id in self.connections:
                success = await self.send_bytes_to_device(device.id, binary_data)
                if success:
                    logger.info(f"Binary data sent to fallback device {device.name}")
                    return True
        
        logger.warning("No available Android devices for binary routing")
        return False
    
    async def route_message(self, message: SignikMessage, sender_ws: WebSocket) -> None:
        """Route messages between devices based on message type and document state."""
        logger.info(f"Routing message type '{message.type}' from device {message.sender_device_id}")
        
        if message.type == "sendStart":
            await self._handle_send_start(message)
        
        elif message.type == "signaturePreview":
            await self._handle_signature_preview(message)
        
        elif message.type in ["signatureAccepted", "signatureDeclined"]:
            await self._handle_signature_review(message)
        
        elif message.type == "signedComplete":
            await self._handle_signed_complete(message)
        
        elif message.type == "connectionRequest":
            # Handle connection request forwarding
            if message.device_id and message.device_id in self.connections:
                await self.send_to_device(message.device_id, message.dict())
        
        else:
            logger.warning(f"Unknown message type: {message.type}")
    
    async def _handle_send_start(self, message: SignikMessage) -> None:
        """Handle PDF send start message from Windows to Android."""
        if not message.doc_id:
            logger.warning("sendStart message missing doc_id")
            return
        
        doc = await self.storage.get_document(message.doc_id)
        if not doc:
            logger.warning(f"Document {message.doc_id} not found")
            return
        
        # Update document status
        await self.storage.update_document_status(
            message.doc_id, 
            DocStatus.SENT
        )
        
        # Determine target device
        target_device_id = None
        
        if message.device_id:
            # Use specified target device
            device = await self.storage.get_device(message.device_id)
            if device and device.is_online:
                target_device_id = message.device_id
                self.last_target_device = target_device_id
                logger.info(f"Using specified target device: {device.name}")
        
        if not target_device_id:
            # Fallback: find first available Android device
            android_devices = await self.storage.get_all_devices(
                device_type=DeviceType.ANDROID,
                online_only=True
            )
            
            if android_devices:
                target_device_id = android_devices[0].id
                self.last_target_device = target_device_id
                logger.info(f"Using fallback device: {android_devices[0].name}")
        
        if target_device_id and target_device_id in self.connections:
            # Update document with target device
            await self.storage.update_document_status(
                message.doc_id,
                DocStatus.SENT,
                android_device_id=target_device_id
            )
            
            # Send message
            await self.connections[target_device_id].send_text(message.json())
            
            # Send PDF data if available
            if doc.pdf_data:
                await self.connections[target_device_id].send_bytes(doc.pdf_data)
                logger.info(f"Sent PDF data ({len(doc.pdf_data)} bytes) to device")
        else:
            logger.error(f"No available target device for document {message.doc_id}")
    
    async def _handle_signature_preview(self, message: SignikMessage) -> None:
        """Handle signature preview from Android to Windows."""
        if not message.doc_id:
            return
        
        doc = await self.storage.get_document(message.doc_id)
        if not doc:
            return
        
        # Update document with signature data
        await self.storage.update_document_status(
            message.doc_id,
            doc.status,  # Keep current status
            signature_data=message.data
        )
        
        # Forward to Windows device
        if doc.windows_device_id and doc.windows_device_id in self.connections:
            await self.connections[doc.windows_device_id].send_text(message.json())
    
    async def _handle_signature_review(self, message: SignikMessage) -> None:
        """Handle signature acceptance/rejection from Windows."""
        if not message.doc_id:
            return
        
        doc = await self.storage.get_document(message.doc_id)
        if not doc:
            return
        
        # Update document status
        new_status = DocStatus.SIGNED if message.type == "signatureAccepted" else DocStatus.DECLINED
        await self.storage.update_document_status(message.doc_id, new_status)
        
        # Forward to Android device
        if doc.android_device_id and doc.android_device_id in self.connections:
            await self.connections[doc.android_device_id].send_text(message.json())
    
    async def _handle_signed_complete(self, message: SignikMessage) -> None:
        """Handle final signed PDF completion."""
        if not message.doc_id:
            return
        
        await self.storage.update_document_status(
            message.doc_id,
            DocStatus.DELIVERED
        )