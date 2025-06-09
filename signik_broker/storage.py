"""In-memory storage manager for Signik Broker."""
from typing import Dict, Optional, List
from datetime import datetime
import asyncio
import logging

from models import (
    Device, Document, DeviceConnection, DeviceType, 
    DocStatus, ConnectionStatus
)

logger = logging.getLogger(__name__)


class StorageManager:
    """Manages in-memory storage for devices, documents, and connections."""
    
    def __init__(self):
        self.devices: Dict[str, Device] = {}
        self.documents: Dict[str, Document] = {}
        self.device_connections: Dict[str, DeviceConnection] = {}
        self._lock = asyncio.Lock()
    
    async def add_device(self, device: Device) -> None:
        """Add or update a device."""
        async with self._lock:
            self.devices[device.id] = device
    
    async def get_device(self, device_id: str) -> Optional[Device]:
        """Get a device by ID."""
        return self.devices.get(device_id)
    
    async def find_device_by_name_and_type(self, name: str, device_type: DeviceType) -> Optional[Device]:
        """Find a device by name and type (for deduplication)."""
        for device in self.devices.values():
            if device.name == name and device.device_type == device_type:
                return device
        return None
    
    async def get_all_devices(self, device_type: Optional[DeviceType] = None, online_only: bool = False) -> List[Device]:
        """Get all devices with optional filtering."""
        devices = list(self.devices.values())
        
        if device_type:
            devices = [d for d in devices if d.device_type == device_type]
        
        if online_only:
            devices = [d for d in devices if d.is_online]
        
        return devices
    
    async def update_device_heartbeat(self, device_id: str) -> bool:
        """Update device heartbeat timestamp."""
        async with self._lock:
            if device_id in self.devices:
                self.devices[device_id].last_heartbeat = datetime.now()
                self.devices[device_id].is_online = True
                return True
            return False
    
    async def update_device_status(self, device_id: str, is_online: bool) -> None:
        """Update device online status."""
        async with self._lock:
            if device_id in self.devices:
                self.devices[device_id].is_online = is_online
    
    async def add_document(self, document: Document) -> None:
        """Add a document to the queue."""
        async with self._lock:
            self.documents[document.id] = document
    
    async def get_document(self, doc_id: str) -> Optional[Document]:
        """Get a document by ID."""
        return self.documents.get(doc_id)
    
    async def get_all_documents(self, status: Optional[DocStatus] = None) -> List[Document]:
        """Get all documents with optional status filter."""
        documents = list(self.documents.values())
        
        if status:
            documents = [d for d in documents if d.status == status]
        
        return documents
    
    async def update_document_status(self, doc_id: str, status: DocStatus, **kwargs) -> bool:
        """Update document status and optional fields."""
        async with self._lock:
            if doc_id in self.documents:
                doc = self.documents[doc_id]
                doc.status = status
                doc.updated_at = datetime.now()
                
                # Update any additional fields
                for key, value in kwargs.items():
                    if hasattr(doc, key):
                        setattr(doc, key, value)
                
                return True
            return False
    
    async def add_connection(self, connection: DeviceConnection) -> None:
        """Add a device connection."""
        async with self._lock:
            self.device_connections[connection.id] = connection
    
    async def get_connection(self, connection_id: str) -> Optional[DeviceConnection]:
        """Get a connection by ID."""
        return self.device_connections.get(connection_id)
    
    async def get_device_connections(self, device_id: str) -> List[DeviceConnection]:
        """Get all connections for a specific device."""
        connections = []
        for conn in self.device_connections.values():
            if conn.windows_device_id == device_id or conn.android_device_id == device_id:
                connections.append(conn)
        return connections
    
    async def connection_exists(self, device1_id: str, device2_id: str) -> bool:
        """Check if a connection exists between two devices."""
        for conn in self.device_connections.values():
            if ((conn.windows_device_id == device1_id and conn.android_device_id == device2_id) or
                (conn.android_device_id == device1_id and conn.windows_device_id == device2_id)):
                return True
        return False
    
    async def update_connection_status(self, connection_id: str, status: ConnectionStatus) -> bool:
        """Update connection status."""
        async with self._lock:
            if connection_id in self.device_connections:
                conn = self.device_connections[connection_id]
                conn.status = status
                conn.updated_at = datetime.now()
                return True
            return False
    
    async def delete_connection(self, connection_id: str) -> bool:
        """Delete a connection."""
        async with self._lock:
            if connection_id in self.device_connections:
                del self.device_connections[connection_id]
                return True
            return False
    
    async def get_all_connections(self, status: Optional[ConnectionStatus] = None) -> List[DeviceConnection]:
        """Get all connections with optional status filter."""
        connections = list(self.device_connections.values())
        
        if status:
            connections = [c for c in connections if c.status == status]
        
        return connections
    
    async def check_device_timeouts(self, timeout_seconds: int = 30) -> None:
        """Check and update device online status based on heartbeat timeout."""
        now = datetime.now()
        for device in self.devices.values():
            time_diff = (now - device.last_heartbeat).total_seconds()
            if time_diff > timeout_seconds and device.is_online:
                await self.update_device_status(device.id, False)
                logger.info(f"Device {device.name} ({device.id}) marked offline - no heartbeat for {time_diff:.0f}s")