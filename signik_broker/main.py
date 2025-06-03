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

class Device(BaseModel):
    id: str
    name: str
    device_type: DeviceType
    ip_address: str
    last_heartbeat: datetime
    is_online: bool = True

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

# In-memory storage (will be replaced with proper DB later)
devices: Dict[str, Device] = {}
documents: Dict[str, Document] = {}
connections: Dict[str, WebSocket] = {}
last_target_device: Optional[str] = None  # Track the last selected device for binary routing

@app.post("/register_device")
async def register_device(request: RegisterDeviceRequest):
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 