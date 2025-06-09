#!/usr/bin/env python3
"""
Test script for Signik Device Connection Management System
Demonstrates the full workflow of device registration, connection requests, 
and many-to-many device relationships.
"""

import requests
import json
import time
import asyncio
import websockets
import threading
from datetime import datetime

BROKER_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000"

class TestDevice:
    def __init__(self, name, device_type, ip_address):
        self.name = name
        self.device_type = device_type
        self.ip_address = ip_address
        self.device_id = None
        self.websocket = None
        self.connections = []
        
    async def register(self):
        """Register this device with the broker"""
        payload = {
            "device_name": self.name,
            "device_type": self.device_type,
            "ip_address": self.ip_address
        }
        
        response = requests.post(f"{BROKER_URL}/register_device", json=payload)
        if response.status_code == 200:
            result = response.json()
            self.device_id = result["device_id"]
            print(f"✅ {self.name} registered with ID: {self.device_id}")
            return True
        else:
            print(f"❌ {self.name} registration failed: {response.text}")
            return False
    
    async def connect_websocket(self):
        """Connect to WebSocket for real-time communication"""
        if not self.device_id:
            print(f"❌ {self.name} cannot connect WebSocket - not registered")
            return False
            
        try:
            uri = f"{WS_URL}/ws/{self.device_id}"
            self.websocket = await websockets.connect(uri)
            print(f"🔌 {self.name} WebSocket connected")
            
            # Start listening for messages
            asyncio.create_task(self.listen_for_messages())
            return True
        except Exception as e:
            print(f"❌ {self.name} WebSocket connection failed: {e}")
            return False
    
    async def listen_for_messages(self):
        """Listen for incoming WebSocket messages"""
        try:
            async for message in self.websocket:
                data = json.loads(message)
                await self.handle_message(data)
        except Exception as e:
            print(f"❌ {self.name} message listening error: {e}")
    
    async def handle_message(self, message):
        """Handle incoming messages"""
        msg_type = message.get("type")
        
        if msg_type == "connectionRequest":
            connection_id = message.get("connection_id")
            from_device = message.get("from_device", {})
            from_name = from_device.get("name", "Unknown")
            
            print(f"📱 {self.name} received connection request from {from_name}")
            
            # Auto-accept connection requests for demo
            await self.respond_to_connection(connection_id, "connected")
            
        elif msg_type == "connectionStatusUpdate":
            connection_id = message.get("connection_id")
            status = message.get("status")
            print(f"🔄 {self.name} connection {connection_id[:8]}... status: {status}")
            
        elif msg_type == "connectionRemoved":
            connection_id = message.get("connection_id")
            print(f"🗑️ {self.name} connection {connection_id[:8]}... removed")
    
    async def respond_to_connection(self, connection_id, status):
        """Respond to a connection request"""
        payload = {"status": status}
        response = requests.put(f"{BROKER_URL}/connections/{connection_id}", json=payload)
        
        if response.status_code == 200:
            print(f"✅ {self.name} {status} connection {connection_id[:8]}...")
        else:
            print(f"❌ {self.name} failed to respond to connection: {response.text}")
    
    async def connect_to_device(self, target_device_id):
        """Initiate connection to another device"""
        payload = {"target_device_id": target_device_id}
        response = requests.post(f"{BROKER_URL}/devices/{self.device_id}/connect", json=payload)
        
        if response.status_code == 200:
            result = response.json()
            print(f"📤 {self.name} sent connection request (ID: {result.get('connection_id', 'unknown')[:8]}...)")
            return True
        else:
            print(f"❌ {self.name} connection request failed: {response.text}")
            return False
    
    async def send_heartbeat(self):
        """Send heartbeat to maintain online status"""
        if not self.device_id:
            return
            
        response = requests.post(f"{BROKER_URL}/heartbeat/{self.device_id}")
        if response.status_code == 200:
            print(f"💓 {self.name} heartbeat sent")
        else:
            print(f"❌ {self.name} heartbeat failed")
    
    def get_my_connections(self):
        """Get current connections for this device"""
        if not self.device_id:
            return []
            
        response = requests.get(f"{BROKER_URL}/devices/{self.device_id}/connections")
        if response.status_code == 200:
            return response.json().get("connections", [])
        return []

def get_all_devices():
    """Get all devices from broker"""
    response = requests.get(f"{BROKER_URL}/devices")
    if response.status_code == 200:
        return response.json().get("devices", [])
    return []

def get_online_devices(device_type=None):
    """Get online devices from broker"""
    url = f"{BROKER_URL}/devices/online"
    if device_type:
        url += f"?device_type={device_type}"
    
    response = requests.get(url)
    if response.status_code == 200:
        return response.json().get("devices", [])
    return []

def get_all_connections():
    """Get all device connections"""
    response = requests.get(f"{BROKER_URL}/connections")
    if response.status_code == 200:
        return response.json().get("connections", [])
    return []

def print_devices_table(devices, title="Devices"):
    """Print devices in a nice table format"""
    print(f"\n📋 {title}")
    print("=" * 80)
    if not devices:
        print("No devices found")
        return
    
    print(f"{'Name':<20} {'Type':<10} {'IP Address':<15} {'Status':<10} {'ID':<10}")
    print("-" * 80)
    for device in devices:
        name = device.get("name", "Unknown")[:19]
        device_type = device.get("device_type", "Unknown")[:9]
        ip = device.get("ip_address", "Unknown")[:14]
        status = "Online" if device.get("is_online") else "Offline"
        device_id = device.get("id", "Unknown")[:8] + "..."
        print(f"{name:<20} {device_type:<10} {ip:<15} {status:<10} {device_id:<10}")

def print_connections_table(connections, title="Device Connections"):
    """Print connections in a nice table format"""
    print(f"\n🔗 {title}")
    print("=" * 100)
    if not connections:
        print("No connections found")
        return
    
    print(f"{'Connection ID':<15} {'Windows Device':<20} {'Android Device':<20} {'Status':<12} {'Created':<15}")
    print("-" * 100)
    for conn in connections:
        conn_id = conn.get("id", "Unknown")[:12] + "..."
        win_device = conn.get("windows_device", {}).get("name", "Unknown")[:19]
        android_device = conn.get("android_device", {}).get("name", "Unknown")[:19]
        status = conn.get("status", "Unknown")[:11]
        created = conn.get("created_at", "Unknown")[:14]
        print(f"{conn_id:<15} {win_device:<20} {android_device:<20} {status:<12} {created:<15}")

async def demo_workflow():
    """Demonstrate the complete device connection workflow"""
    print("🚀 Starting Signik Device Connection Management Demo")
    print("=" * 60)
    
    # Create test devices
    devices = [
        TestDevice("Windows-PC-1", "windows", "192.168.1.100"),
        TestDevice("Windows-PC-2", "windows", "192.168.1.101"), 
        TestDevice("Android-Phone-1", "android", "192.168.1.200"),
        TestDevice("Android-Phone-2", "android", "192.168.1.201"),
        TestDevice("Android-Tablet-1", "android", "192.168.1.202"),
    ]
    
    # Phase 1: Register all devices
    print("\n📝 Phase 1: Device Registration")
    print("-" * 40)
    for device in devices:
        success = await device.register()
        if not success:
            print(f"❌ Skipping {device.name} due to registration failure")
            devices.remove(device)
        await asyncio.sleep(0.5)
    
    # Phase 2: Connect WebSockets
    print("\n🔌 Phase 2: WebSocket Connections")
    print("-" * 40)
    for device in devices:
        await device.connect_websocket()
        await asyncio.sleep(0.5)
    
    # Phase 3: Send heartbeats
    print("\n💓 Phase 3: Heartbeat Status")
    print("-" * 40)
    for device in devices:
        await device.send_heartbeat()
        await asyncio.sleep(0.3)
    
    # Phase 4: Display current state
    await asyncio.sleep(2)
    print_devices_table(get_all_devices(), "All Registered Devices")
    print_devices_table(get_online_devices(), "Online Devices")
    print_devices_table(get_online_devices("android"), "Online Android Devices")
    print_devices_table(get_online_devices("windows"), "Online Windows Devices")
    
    # Phase 5: Create connections
    print("\n🤝 Phase 5: Creating Device Connections")
    print("-" * 40)
    
    # Windows PC 1 connects to Android devices
    windows_pc1 = devices[0]  # Windows-PC-1
    android_devices = [d for d in devices if d.device_type == "android"]
    
    for android_device in android_devices:
        print(f"📱 {windows_pc1.name} connecting to {android_device.name}")
        await windows_pc1.connect_to_device(android_device.device_id)
        await asyncio.sleep(1)  # Give time for WebSocket messages
    
    # Windows PC 2 connects to some Android devices
    if len(devices) > 1:
        windows_pc2 = devices[1]  # Windows-PC-2
        for android_device in android_devices[:2]:  # Connect to first 2 Android devices
            print(f"📱 {windows_pc2.name} connecting to {android_device.name}")
            await windows_pc2.connect_to_device(android_device.device_id)
            await asyncio.sleep(1)
    
    # Phase 6: Display connections
    await asyncio.sleep(3)  # Wait for all connections to process
    print_connections_table(get_all_connections(), "All Device Connections")
    
    # Phase 7: Show individual device connections
    print("\n📱 Phase 7: Individual Device Connections")
    print("-" * 40)
    for device in devices:
        connections = device.get_my_connections()
        if connections:
            print(f"\n{device.name} connections:")
            for conn in connections:
                other_device = conn.get("other_device", {})
                status = conn.get("status")
                print(f"  → {other_device.get('name', 'Unknown')} ({status})")
        else:
            print(f"\n{device.name}: No connections")
    
    # Phase 8: Connection management demo
    print("\n⚡ Phase 8: Connection Management Demo")
    print("-" * 40)
    
    connections = get_all_connections()
    if connections:
        # Disconnect first connection
        first_conn = connections[0]
        conn_id = first_conn["id"]
        
        print(f"🔌 Disconnecting connection {conn_id[:8]}...")
        payload = {"status": "disconnected"}
        response = requests.put(f"{BROKER_URL}/connections/{conn_id}", json=payload)
        
        if response.status_code == 200:
            print("✅ Connection disconnected successfully")
        else:
            print(f"❌ Disconnection failed: {response.text}")
        
        await asyncio.sleep(2)
        print_connections_table(get_all_connections(), "Updated Connections")
    
    print("\n🎉 Demo completed! Check the Windows app to see the real-time updates.")
    print("💡 The Windows Device Manager should show all devices and connections.")

async def main():
    """Main function"""
    try:
        # Test broker connectivity
        response = requests.get(f"{BROKER_URL}/devices")
        if response.status_code != 200:
            print(f"❌ Cannot connect to broker at {BROKER_URL}")
            print("Make sure the Signik broker is running!")
            return
        
        print(f"✅ Connected to Signik broker at {BROKER_URL}")
        await demo_workflow()
        
    except KeyboardInterrupt:
        print("\n⏹️ Demo interrupted by user")
    except Exception as e:
        print(f"❌ Demo failed: {e}")

if __name__ == "__main__":
    print("🔧 Signik Device Connection Management Test")
    print("Make sure the broker is running: python signik_broker/main.py")
    print("And the Windows app is open for real-time updates!")
    print()
    
    asyncio.run(main()) 