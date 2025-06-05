"""Signik Broker - FastAPI server for device and document management."""
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, WebSocket, Depends
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

from models import (
    DeviceType, DocStatus, ConnectionStatus,
    RegisterDeviceRequest, EnqueueDocRequest, ConnectDeviceRequest,
    UpdateConnectionRequest
)
from storage import StorageManager
from websocket_manager import WebSocketManager
from api_routes import APIRoutes

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global instances
storage = StorageManager()
ws_manager = WebSocketManager(storage)
api_routes = APIRoutes(storage, ws_manager)


async def periodic_device_check():
    """Background task to check device heartbeats."""
    while True:
        try:
            await storage.check_device_timeouts(timeout_seconds=30)
        except Exception as e:
            logger.error(f"Error in device check task: {e}")
        await asyncio.sleep(10)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    logger.info("Starting Signik Broker...")
    task = asyncio.create_task(periodic_device_check())
    
    yield
    
    # Shutdown
    logger.info("Shutting down Signik Broker...")
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


# Create FastAPI app
app = FastAPI(
    title="Signik Broker",
    version="2.0.0",
    description="Refactored broker service for Signik PDF signing solution",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Device Management Endpoints
@app.post("/register_device", response_model=dict)
async def register_device(request: RegisterDeviceRequest):
    """Register a new device or update existing one."""
    response = await api_routes.register_device(request)
    return response.dict()


@app.get("/devices")
async def get_devices(device_type: Optional[DeviceType] = None):
    """Get all registered devices."""
    return await api_routes.get_devices(device_type)


@app.get("/devices/online")
async def get_online_devices(device_type: Optional[DeviceType] = None):
    """Get only online devices."""
    return await api_routes.get_online_devices(device_type)


@app.post("/heartbeat/{device_id}")
async def heartbeat(device_id: str):
    """Process device heartbeat."""
    return await api_routes.heartbeat(device_id)


# Document Management Endpoints
@app.post("/enqueue_doc", response_model=dict)
async def enqueue_document(request: EnqueueDocRequest):
    """Add a document to the signing queue."""
    response = await api_routes.enqueue_document(request)
    return response.dict()


@app.get("/documents")
async def get_documents(status: Optional[DocStatus] = None):
    """Get all documents."""
    return await api_routes.get_documents(status)


# Connection Management Endpoints
@app.post("/devices/{device_id}/connect")
async def connect_device(device_id: str, request: ConnectDeviceRequest):
    """Initiate a connection between two devices."""
    return await api_routes.connect_device(device_id, request)


@app.get("/devices/{device_id}/connections")
async def get_device_connections(device_id: str):
    """Get all connections for a specific device."""
    return await api_routes.get_device_connections(device_id)


@app.put("/connections/{connection_id}")
async def update_connection(connection_id: str, request: UpdateConnectionRequest):
    """Update connection status."""
    return await api_routes.update_connection(connection_id, request)


@app.get("/connections")
async def get_all_connections(status: Optional[ConnectionStatus] = None):
    """Get all device connections."""
    return await api_routes.get_all_connections(status)


@app.delete("/connections/{connection_id}")
async def delete_connection(connection_id: str):
    """Remove a device connection."""
    return await api_routes.delete_connection(connection_id)


# WebSocket Endpoint
@app.websocket("/ws/{device_id}")
async def websocket_endpoint(websocket: WebSocket, device_id: str):
    """WebSocket endpoint for real-time communication."""
    await api_routes.handle_websocket(websocket, device_id)


# Health Check
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    device_count = len(storage.devices)
    online_count = sum(1 for d in storage.devices.values() if d.is_online)
    
    return {
        "status": "healthy",
        "devices": {
            "total": device_count,
            "online": online_count
        },
        "documents": len(storage.documents),
        "connections": len(storage.device_connections)
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="info",
        reload=False
    )