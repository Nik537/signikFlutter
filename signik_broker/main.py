from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional, Any
import json
import uuid
import asyncio
from datetime import datetime
from enum import Enum

app = FastAPI(title="Signik Broker", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class DeviceType(str, Enum):
    WINDOWS = "windows"
    ANDROID = "android"

class DocStatus(str, Enum):
    QUEUED = "queued"
    SENT = "sent"
    SIGNED = "signed"
    DECLINED = "declined"
    DEFERRED = "deferred"
    DELIVERED = "delivered"

class ConnectionStatus(str, Enum):
    PENDING = "pending"
    CONNECTED = "connected"
    DISCONNECTED = "disconnected"
    REJECTED = "rejected"

class Device(BaseModel):
    id: str
    name: str
    device_type: DeviceType
    ip_address: str
    last_heartbeat: datetime
    is_online: bool = True

class DeviceConnection(BaseModel):
    id: str
    windows_device_id: str
    android_device_id: str
    status: ConnectionStatus
    created_at: datetime
    updated_at: datetime
    initiated_by: str  # device_id that initiated the connection

class Document(BaseModel):
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
    type: str
    name: Optional[str] = None
    data: Optional[Any] = None
    doc_id: Optional[str] = None
    device_id: Optional[str] = None
    sender_device_id: Optional[str] = None

class RegisterDeviceRequest(BaseModel):
    device_name: str
    device_type: DeviceType
    ip_address: str

class EnqueueDocRequest(BaseModel):
    name: str
    windows_device_id: str
    pdf_data: Optional[str] = None  # Base64 encoded

class ConnectDeviceRequest(BaseModel):
    target_device_id: str

class UpdateConnectionRequest(BaseModel):
    status: ConnectionStatus

# In-memory storage (will be replaced with proper DB later)
devices: Dict[str, Device] = {}
documents: Dict[str, Document] = {}
device_connections: Dict[str, DeviceConnection] = {}
connections: Dict[str, WebSocket] = {}
last_target_device: Optional[str] = None  # Track the last selected device for binary routing

@app.post("/register_device")
async def register_device(request: RegisterDeviceRequest):
    # Check if a device with the same name and type already exists
    existing_device = None
    for device in devices.values():
        if (device.name == request.device_name and 
            device.device_type == request.device_type):
            existing_device = device
            break
    
    if existing_device:
        # Update existing device info and mark as online
        existing_device.ip_address = request.ip_address
        existing_device.last_heartbeat = datetime.now()
        existing_device.is_online = True
        return {"device_id": existing_device.id, "message": "Device updated successfully"}
    else:
        # Create new device
        device_id = str(uuid.uuid4())
        device = Device(
            id=device_id,
            name=request.device_name,
            device_type=request.device_type,
            ip_address=request.ip_address,
            last_heartbeat=datetime.now()
        )
        devices[device_id] = device
        return {"device_id": device_id, "message": "Device registered successfully"}

@app.post("/enqueue_doc")
async def enqueue_document(request: EnqueueDocRequest):
    if request.windows_device_id not in devices:
        raise HTTPException(status_code=404, detail="Windows device not found")
    
    doc_id = str(uuid.uuid4())
    # Convert base64 string to bytes if provided
    pdf_data = None
    if request.pdf_data:
        import base64
        pdf_data = base64.b64decode(request.pdf_data)
    
    document = Document(
        id=doc_id,
        name=request.name,
        status=DocStatus.QUEUED,
        created_at=datetime.now(),
        updated_at=datetime.now(),
        windows_device_id=request.windows_device_id,
        pdf_data=pdf_data
    )
    documents[doc_id] = document
    
    return {"doc_id": doc_id, "message": "Document enqueued successfully"}

@app.get("/devices")
async def get_devices(device_type: Optional[DeviceType] = None):
    filtered_devices = devices.values()
    if device_type:
        filtered_devices = [d for d in filtered_devices if d.device_type == device_type]
    
    return {"devices": [d.dict() for d in filtered_devices]}

@app.get("/devices/online")
async def get_online_devices(device_type: Optional[DeviceType] = None):
    """Get only online devices - useful for target device selection"""
    filtered_devices = [d for d in devices.values() if d.is_online]
    if device_type:
        filtered_devices = [d for d in filtered_devices if d.device_type == device_type]
    
    return {"devices": [d.dict() for d in filtered_devices]}

@app.get("/documents")
async def get_documents(status: Optional[DocStatus] = None):
    filtered_docs = documents.values()
    if status:
        filtered_docs = [d for d in filtered_docs if d.status == status]
    
    return {"documents": [d.dict() for d in filtered_docs]}

@app.post("/heartbeat/{device_id}")
async def heartbeat(device_id: str):
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    devices[device_id].last_heartbeat = datetime.now()
    devices[device_id].is_online = True
    return {"message": "Heartbeat received"}

@app.websocket("/ws/{device_id}")
async def websocket_endpoint(websocket: WebSocket, device_id: str):
    await websocket.accept()
    
    if device_id not in devices:
        await websocket.close(code=1008, reason="Device not registered")
        return
    
    connections[device_id] = websocket
    
    try:
        while True:
            # Receive message (could be text or binary)
            message_data = await websocket.receive()
            
            if "text" in message_data:
                # Handle JSON message
                try:
                    data = message_data["text"]
                    message = SignikMessage.parse_raw(data)
                    # Store the sender device ID separately, don't override the target device_id
                    message.sender_device_id = device_id
                    
                    # Route message based on type
                    await route_message(message, websocket)
                except Exception as e:
                    print(f"Error parsing message from {device_id}: {e}")
                    
            elif "bytes" in message_data:
                # Handle binary data (PDF bytes)
                binary_data = message_data["bytes"]
                await route_binary_data(binary_data, device_id)
                
    except WebSocketDisconnect:
        print(f"Device {device_id} disconnected")
        if device_id in connections:
            del connections[device_id]
        devices[device_id].is_online = False

async def route_binary_data(binary_data: bytes, sender_device_id: str):
    """Route binary data (PDF bytes) to the appropriate device"""
    global last_target_device
    
    print(f"DEBUG: 📦 Routing {len(binary_data)} bytes from {sender_device_id}")
    print(f"DEBUG: last_target_device = {last_target_device}")
    
    # If we have a last target device from a recent message, use it
    if last_target_device and last_target_device in connections:
        target_device = devices.get(last_target_device)
        if target_device and target_device.is_online:
            print(f"DEBUG: 🎯 Sending binary data to target device: {target_device.name} ({last_target_device})")
            await connections[last_target_device].send_bytes(binary_data)
            print(f"DEBUG: ✅ Binary data sent successfully to {target_device.name}")
            return
        else:
            print(f"DEBUG: ❌ Last target device {last_target_device} not available")
    
    # Fallback: send to first available Android device
    print("DEBUG: Using fallback for binary routing")
    android_devices = [d for d in devices.values() 
                     if d.device_type == DeviceType.ANDROID and d.is_online]
    
    if android_devices:
        target_device = android_devices[0]
        
        if target_device.id in connections:
            print(f"DEBUG: 📤 Fallback: sending binary data to {target_device.name}")
            await connections[target_device.id].send_bytes(binary_data)
        else:
            print(f"DEBUG: ❌ Fallback device {target_device.id} not connected")
    else:
        print("DEBUG: ❌ No Android devices available for binary routing")

async def route_message(message: SignikMessage, sender_ws: WebSocket):
    """Route messages between devices based on message type and document state"""
    global last_target_device
    
    print(f"DEBUG: Routing message type '{message.type}' from device {message.sender_device_id}")
    
    if message.type == "sendStart":
        # Windows -> Android: Send PDF for signing
        print(f"DEBUG: sendStart message - doc_id: {message.doc_id}, target device_id: {message.device_id}")
        
        if message.doc_id and message.doc_id in documents:
            doc = documents[message.doc_id]
            doc.status = DocStatus.SENT
            doc.updated_at = datetime.now()
            
            # Use the specific target device if provided in the message
            target_device_id = None
            
            if message.device_id:
                # Use the device ID specified in the message (this is the target device)
                target_device_id = message.device_id
                print(f"DEBUG: Checking if target device {target_device_id} is available...")
                
                if target_device_id in devices and devices[target_device_id].is_online:
                    target_device = devices[target_device_id]
                    last_target_device = target_device_id  # Remember for binary routing
                    print(f"DEBUG: ✅ Routing to specified target device: {target_device.name} ({target_device_id})")
                else:
                    print(f"DEBUG: ❌ Specified target device {target_device_id} not available")
                    print(f"DEBUG: Available devices: {list(devices.keys())}")
                    print(f"DEBUG: Device online status: {[(d.id, d.is_online) for d in devices.values()]}")
                    target_device_id = None
            
            if not target_device_id:
                # Fallback: find first available Android device
                print("DEBUG: Using fallback - finding first available Android device")
                android_devices = [d for d in devices.values() 
                                 if d.device_type == DeviceType.ANDROID and d.is_online]
                
                if android_devices:
                    target_device = android_devices[0]
                    target_device_id = target_device.id
                    last_target_device = target_device_id
                    print(f"DEBUG: Using fallback device: {target_device.name} ({target_device_id})")
            
            if target_device_id and target_device_id in connections:
                doc.android_device_id = target_device_id
                target_device = devices[target_device_id]
                
                print(f"DEBUG: 🚀 Sending message to {target_device.name} ({target_device_id})")
                # Send the message
                await connections[target_device_id].send_text(message.json())
                
                # If the document has PDF data stored, send it too
                if doc.pdf_data:
                    print(f"DEBUG: 📄 Sending PDF data ({len(doc.pdf_data)} bytes) to {target_device.name}")
                    await connections[target_device_id].send_bytes(doc.pdf_data)
            else:
                print(f"DEBUG: ❌ No available target device found for document {message.doc_id}")
                print(f"DEBUG: target_device_id: {target_device_id}")
                print(f"DEBUG: connections: {list(connections.keys())}")
    
    elif message.type == "signaturePreview":
        # Android -> Windows: Send signature for review
        if message.doc_id and message.doc_id in documents:
            doc = documents[message.doc_id]
            doc.signature_data = message.data
            doc.updated_at = datetime.now()
            
            if doc.windows_device_id and doc.windows_device_id in connections:
                await connections[doc.windows_device_id].send_text(message.json())
    
    elif message.type in ["signatureAccepted", "signatureDeclined"]:
        # Windows -> Android: Review result
        if message.doc_id and message.doc_id in documents:
            doc = documents[message.doc_id]
            
            if message.type == "signatureAccepted":
                doc.status = DocStatus.SIGNED
            else:
                doc.status = DocStatus.DECLINED
            
            doc.updated_at = datetime.now()
            
            if doc.android_device_id and doc.android_device_id in connections:
                await connections[doc.android_device_id].send_text(message.json())
    
    elif message.type == "signedComplete":
        # Final signed PDF
        if message.doc_id and message.doc_id in documents:
            doc = documents[message.doc_id]
            doc.status = DocStatus.DELIVERED
            doc.updated_at = datetime.now()

# Background task to check device heartbeats
async def check_device_status():
    while True:
        now = datetime.now()
        for device in devices.values():
            time_diff = (now - device.last_heartbeat).total_seconds()
            if time_diff > 30:  # 30 seconds timeout
                device.is_online = False
        
        await asyncio.sleep(10)  # Check every 10 seconds

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(check_device_status())

@app.post("/devices/{device_id}/connect")
async def connect_device(device_id: str, request: ConnectDeviceRequest):
    """Initiate a connection between two devices"""
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Source device not found")
    
    if request.target_device_id not in devices:
        raise HTTPException(status_code=404, detail="Target device not found")
    
    source_device = devices[device_id]
    target_device = devices[request.target_device_id]
    
    # Ensure devices are of different types
    if source_device.device_type == target_device.device_type:
        raise HTTPException(status_code=400, detail="Cannot connect devices of the same type")
    
    # Check if connection already exists
    for conn in device_connections.values():
        if ((conn.windows_device_id == device_id and conn.android_device_id == request.target_device_id) or
            (conn.android_device_id == device_id and conn.windows_device_id == request.target_device_id)):
            raise HTTPException(status_code=400, detail="Connection already exists")
    
    # Create connection
    connection_id = str(uuid.uuid4())
    windows_id = device_id if source_device.device_type == DeviceType.WINDOWS else request.target_device_id
    android_id = request.target_device_id if target_device.device_type == DeviceType.ANDROID else device_id
    
    connection = DeviceConnection(
        id=connection_id,
        windows_device_id=windows_id,
        android_device_id=android_id,
        status=ConnectionStatus.PENDING,
        created_at=datetime.now(),
        updated_at=datetime.now(),
        initiated_by=device_id
    )
    device_connections[connection_id] = connection
    
    # Notify target device about connection request
    if request.target_device_id in connections:
        message = {
            "type": "connectionRequest",
            "connection_id": connection_id,
            "from_device": source_device.dict()
        }
        await connections[request.target_device_id].send_text(json.dumps(message))
    
    return {"connection_id": connection_id, "message": "Connection request sent"}

@app.get("/devices/{device_id}/connections")
async def get_device_connections(device_id: str):
    """Get all connections for a specific device"""
    if device_id not in devices:
        raise HTTPException(status_code=404, detail="Device not found")
    
    device_connections_list = []
    for conn in device_connections.values():
        if conn.windows_device_id == device_id or conn.android_device_id == device_id:
            # Get the other device info
            other_device_id = conn.android_device_id if conn.windows_device_id == device_id else conn.windows_device_id
            other_device = devices.get(other_device_id)
            
            connection_info = conn.dict()
            connection_info["other_device"] = other_device.dict() if other_device else None
            device_connections_list.append(connection_info)
    
    return {"connections": device_connections_list}

@app.put("/connections/{connection_id}")
async def update_connection(connection_id: str, request: UpdateConnectionRequest):
    """Update connection status (accept/reject/disconnect)"""
    if connection_id not in device_connections:
        raise HTTPException(status_code=404, detail="Connection not found")
    
    connection = device_connections[connection_id]
    connection.status = request.status
    connection.updated_at = datetime.now()
    
    # Notify both devices about status change
    message = {
        "type": "connectionStatusUpdate",
        "connection_id": connection_id,
        "status": request.status.value
    }
    
    for device_id in [connection.windows_device_id, connection.android_device_id]:
        if device_id in connections:
            await connections[device_id].send_text(json.dumps(message))
    
    return {"message": f"Connection status updated to {request.status.value}"}

@app.get("/connections")
async def get_all_connections(status: Optional[ConnectionStatus] = None):
    """Get all device connections with optional status filter"""
    filtered_connections = device_connections.values()
    if status:
        filtered_connections = [c for c in filtered_connections if c.status == status]
    
    connections_with_devices = []
    for conn in filtered_connections:
        windows_device = devices.get(conn.windows_device_id)
        android_device = devices.get(conn.android_device_id)
        
        conn_info = conn.dict()
        conn_info["windows_device"] = windows_device.dict() if windows_device else None
        conn_info["android_device"] = android_device.dict() if android_device else None
        connections_with_devices.append(conn_info)
    
    return {"connections": connections_with_devices}

@app.delete("/connections/{connection_id}")
async def delete_connection(connection_id: str):
    """Remove a device connection"""
    if connection_id not in device_connections:
        raise HTTPException(status_code=404, detail="Connection not found")
    
    connection = device_connections[connection_id]
    
    # Notify both devices about disconnection
    message = {
        "type": "connectionRemoved",
        "connection_id": connection_id
    }
    
    for device_id in [connection.windows_device_id, connection.android_device_id]:
        if device_id in connections:
            await connections[device_id].send_text(json.dumps(message))
    
    del device_connections[connection_id]
    return {"message": "Connection removed successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 