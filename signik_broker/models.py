"""Data models for Signik Broker."""
from datetime import datetime
from enum import Enum
from typing import Optional, Any
from pydantic import BaseModel, Field


class DeviceType(str, Enum):
    """Supported device types."""
    WINDOWS = "windows"
    ANDROID = "android"


class DocStatus(str, Enum):
    """Document lifecycle states."""
    QUEUED = "queued"
    SENT = "sent"
    SIGNED = "signed"
    DECLINED = "declined"
    DEFERRED = "deferred"
    DELIVERED = "delivered"


class ConnectionStatus(str, Enum):
    """Device connection states."""
    PENDING = "pending"
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    REJECTED = "rejected"


class Device(BaseModel):
    """Device registration model."""
    id: str
    name: str
    device_type: DeviceType
    ip_address: str
    last_heartbeat: datetime
    is_online: bool = True


class DeviceConnection(BaseModel):
    """Many-to-many device connection model."""
    id: str
    windows_device_id: str
    android_device_id: str
    status: ConnectionStatus
    created_at: datetime
    updated_at: datetime
    initiated_by: str  # device_id that initiated the connection


class Document(BaseModel):
    """Document signing workflow model."""
    id: str
    name: str
    status: DocStatus
    created_at: datetime
    updated_at: datetime
    windows_device_id: Optional[str] = None
    android_device_id: Optional[str] = None
    pdf_data: Optional[bytes] = None
    signature_data: Optional[bytes] = None


class SignikMessage(BaseModel):
    """WebSocket message protocol."""
    type: str
    name: Optional[str] = None
    data: Optional[Any] = None
    doc_id: Optional[str] = None
    device_id: Optional[str] = None
    sender_device_id: Optional[str] = None


# API Request/Response Models
class RegisterDeviceRequest(BaseModel):
    """Device registration request."""
    device_name: str = Field(..., min_length=1)
    device_type: DeviceType
    ip_address: str = Field(..., pattern=r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")


class RegisterDeviceResponse(BaseModel):
    """Device registration response."""
    device_id: str
    message: str
    is_update: bool = False


class EnqueueDocRequest(BaseModel):
    """Document enqueue request."""
    name: str = Field(..., min_length=1)
    windows_device_id: str
    pdf_data: Optional[str] = None  # Base64 encoded


class EnqueueDocResponse(BaseModel):
    """Document enqueue response."""
    doc_id: str
    message: str


class ConnectDeviceRequest(BaseModel):
    """Device connection request."""
    target_device_id: str


class UpdateConnectionRequest(BaseModel):
    """Connection status update request."""
    status: ConnectionStatus


class DeviceListResponse(BaseModel):
    """Device list response."""
    devices: list[dict]
    total: int


class DocumentListResponse(BaseModel):
    """Document list response."""
    documents: list[dict]
    total: int


class ConnectionListResponse(BaseModel):
    """Connection list response."""
    connections: list[dict]
    total: int