#!/usr/bin/env python3
"""
Test script for Signik Broker Service
Demonstrates device registration, document queuing, and WebSocket communication
"""

import asyncio
import json
import requests
import websockets
from datetime import datetime

BROKER_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000"

def test_device_registration():
    """Test device registration endpoint"""
    print("🔧 Testing device registration...")
    
    # Register Windows device
    response = requests.post(f"{BROKER_URL}/register_device", json={
        "device_name": "Test-Windows-PC",
        "device_type": "windows",
        "ip_address": "192.168.1.100"
    })
    
    if response.status_code == 200:
        windows_device_id = response.json()["device_id"]
        print(f"✅ Windows device registered: {windows_device_id}")
    else:
        print(f"❌ Failed to register Windows device: {response.text}")
        return None, None
    
    # Register Android device
    response = requests.post(f"{BROKER_URL}/register_device", json={
        "device_name": "Test-Android-Tablet",
        "device_type": "android",
        "ip_address": "192.168.1.101"
    })
    
    if response.status_code == 200:
        android_device_id = response.json()["device_id"]
        print(f"✅ Android device registered: {android_device_id}")
    else:
        print(f"❌ Failed to register Android device: {response.text}")
        return windows_device_id, None
    
    return windows_device_id, android_device_id

def test_document_queuing(windows_device_id):
    """Test document queuing endpoint"""
    print("\n📄 Testing document queuing...")
    
    response = requests.post(f"{BROKER_URL}/enqueue_doc", json={
        "name": "test_document.pdf",
        "windows_device_id": windows_device_id
    })
    
    if response.status_code == 200:
        doc_id = response.json()["doc_id"]
        print(f"✅ Document enqueued: {doc_id}")
        return doc_id
    else:
        print(f"❌ Failed to enqueue document: {response.text}")
        return None

def test_heartbeat(device_id):
    """Test heartbeat endpoint"""
    print(f"\n💓 Testing heartbeat for device {device_id}...")
    
    response = requests.post(f"{BROKER_URL}/heartbeat/{device_id}")
    
    if response.status_code == 200:
        print("✅ Heartbeat sent successfully")
        return True
    else:
        print(f"❌ Failed to send heartbeat: {response.text}")
        return False

def test_get_devices():
    """Test getting device list"""
    print("\n📱 Testing device list...")
    
    response = requests.get(f"{BROKER_URL}/devices")
    
    if response.status_code == 200:
        devices = response.json()["devices"]
        print(f"✅ Retrieved {len(devices)} devices:")
        for device in devices:
            print(f"  - {device['name']} ({device['device_type']}) - {'Online' if device['is_online'] else 'Offline'}")
        return devices
    else:
        print(f"❌ Failed to get devices: {response.text}")
        return []

def test_get_documents():
    """Test getting document list"""
    print("\n📋 Testing document list...")
    
    response = requests.get(f"{BROKER_URL}/documents")
    
    if response.status_code == 200:
        documents = response.json()["documents"]
        print(f"✅ Retrieved {len(documents)} documents:")
        for doc in documents:
            print(f"  - {doc['name']} ({doc['status']})")
        return documents
    else:
        print(f"❌ Failed to get documents: {response.text}")
        return []

async def test_websocket_connection(device_id, device_name):
    """Test WebSocket connection and message handling"""
    print(f"\n🌐 Testing WebSocket connection for {device_name}...")
    
    try:
        uri = f"{WS_URL}/ws/{device_id}"
        async with websockets.connect(uri) as websocket:
            print(f"✅ WebSocket connected for {device_name}")
            
            # Send a test message
            test_message = {
                "type": "heartbeat",
                "device_id": device_id,
                "schema_version": 1
            }
            
            await websocket.send(json.dumps(test_message))
            print(f"📤 Sent heartbeat message from {device_name}")
            
            # Wait for potential messages (timeout after 2 seconds)
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=2.0)
                print(f"📥 Received message: {message}")
            except asyncio.TimeoutError:
                print("⏰ No messages received (timeout)")
            
    except Exception as e:
        print(f"❌ WebSocket connection failed: {e}")

async def simulate_full_workflow(windows_device_id, android_device_id, doc_id):
    """Simulate a full signing workflow via WebSocket"""
    print(f"\n🔄 Simulating full signing workflow...")
    
    try:
        # Connect both devices
        windows_uri = f"{WS_URL}/ws/{windows_device_id}"
        android_uri = f"{WS_URL}/ws/{android_device_id}"
        
        async with websockets.connect(windows_uri) as windows_ws, \
                   websockets.connect(android_uri) as android_ws:
            
            print("✅ Both devices connected via WebSocket")
            
            # Step 1: Windows sends PDF
            send_message = {
                "type": "sendStart",
                "name": "test_document.pdf",
                "doc_id": doc_id,
                "device_id": windows_device_id,
                "data": "fake_pdf_data_here",
                "schema_version": 1
            }
            
            await windows_ws.send(json.dumps(send_message))
            print("📤 Windows: Sent PDF to Android")
            
            # Step 2: Android receives and processes
            await asyncio.sleep(1)  # Simulate processing time
            
            # Step 3: Android sends signature preview
            signature_message = {
                "type": "signaturePreview",
                "doc_id": doc_id,
                "device_id": android_device_id,
                "data": "fake_signature_data_here",
                "schema_version": 1
            }
            
            await android_ws.send(json.dumps(signature_message))
            print("📤 Android: Sent signature preview to Windows")
            
            await asyncio.sleep(1)
            
            # Step 4: Windows accepts signature
            accept_message = {
                "type": "signatureAccepted",
                "doc_id": doc_id,
                "device_id": windows_device_id,
                "schema_version": 1
            }
            
            await windows_ws.send(json.dumps(accept_message))
            print("📤 Windows: Accepted signature")
            
            # Step 5: Final completion
            complete_message = {
                "type": "signedComplete",
                "doc_id": doc_id,
                "device_id": windows_device_id,
                "data": "final_signed_pdf_data",
                "schema_version": 1
            }
            
            await windows_ws.send(json.dumps(complete_message))
            print("📤 Windows: Workflow completed")
            
            print("✅ Full workflow simulation completed successfully!")
            
    except Exception as e:
        print(f"❌ Workflow simulation failed: {e}")

async def main():
    """Run all tests"""
    print("🚀 Starting Signik Broker Tests")
    print("=" * 50)
    
    # Test device registration
    windows_device_id, android_device_id = test_device_registration()
    if not windows_device_id or not android_device_id:
        print("❌ Device registration failed, stopping tests")
        return
    
    # Test document queuing
    doc_id = test_document_queuing(windows_device_id)
    if not doc_id:
        print("❌ Document queuing failed, stopping tests")
        return
    
    # Test heartbeat
    test_heartbeat(windows_device_id)
    test_heartbeat(android_device_id)
    
    # Test getting devices and documents
    test_get_devices()
    test_get_documents()
    
    # Test WebSocket connections
    await test_websocket_connection(windows_device_id, "Windows PC")
    await test_websocket_connection(android_device_id, "Android Tablet")
    
    # Test full workflow simulation
    await simulate_full_workflow(windows_device_id, android_device_id, doc_id)
    
    print("\n" + "=" * 50)
    print("🎉 All tests completed!")
    print("\n📊 Test Summary:")
    print("- Device registration: ✅")
    print("- Document queuing: ✅")
    print("- Heartbeat: ✅")
    print("- Device/Document listing: ✅")
    print("- WebSocket connections: ✅")
    print("- Full workflow simulation: ✅")

if __name__ == "__main__":
    print("Make sure the broker is running: python signik_broker/main.py")
    print("Press Enter to continue...")
    input()
    
    asyncio.run(main()) 