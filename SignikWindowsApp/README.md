# Signik Windows Device Manager

A comprehensive Windows Forms application for managing device connections and document signing workflow between Windows PCs and Android devices.

## Features

### 🔌 **Device Connection Management**
- **Many-to-Many Relationships**: Connect 1 PC to multiple Android devices or 1 Android to multiple PCs
- **Real-time Connection Status**: See online/offline status of all devices
- **Connection Requests**: Send and receive connection requests with accept/reject functionality
- **Automatic Updates**: Real-time updates via WebSocket connections

### 📱 **Device Discovery**
- **All Devices View**: See every device registered in the system
- **Available Devices**: Filter online devices available for connection
- **Device Types**: Filter by Windows/Android devices
- **IP Address Tracking**: Monitor device network information

### 📄 **Document Management**
- **PDF Sending**: Send PDF documents to connected Android devices for signing
- **Connected Device Targeting**: Only send to devices you're connected to
- **Document Status Tracking**: Monitor document workflow status

### ⚡ **Real-time Features**
- **Live Device Status**: Automatic heartbeat monitoring
- **Connection Notifications**: Instant connection request notifications
- **Status Updates**: Real-time connection status changes
- **Auto-refresh**: Automatic data refresh every 5 seconds

## UI Layout

The application features a modern, grid-based layout similar to enterprise data management systems:

### **Top Panel - Device Registration**
- Device name input
- Register & Connect button
- Connection status indicator
- Refresh controls

### **Left Panel - All Devices**
- Complete device registry
- Device type, IP address, and status
- Last seen timestamps

### **Right Panel - Available Devices**
- Online devices available for connection
- Device type filtering (All/Android/Windows)
- Connect button for initiating connections

### **Bottom Panel - My Connections**
- Active device connections
- Connection status (Pending/Connected/Rejected)
- Disconnect and Send PDF controls
- Connection timestamps

## Requirements

- **.NET 8.0** or later
- **Windows 10/11**
- **Network access** to Signik Broker (default: localhost:8000)

## Installation & Setup

1. **Ensure .NET 8.0 is installed**:
   ```bash
   dotnet --version
   ```

2. **Clone and navigate to the project**:
   ```bash
   cd SignikWindowsApp
   ```

3. **Restore dependencies**:
   ```bash
   dotnet restore
   ```

4. **Build the application**:
   ```bash
   dotnet build
   ```

5. **Run the application**:
   ```bash
   dotnet run
   ```
   
   Or use the provided batch file:
   ```bash
   run.bat
   ```

## Usage

### **1. Device Registration**
1. Enter your device name (defaults to computer name)
2. Click "Register & Connect"
3. Wait for successful connection to broker

### **2. Discovering Devices**
1. Use "Refresh All" to update device lists
2. Filter available devices by type using the dropdown
3. View all registered devices in the left panel

### **3. Connecting to Devices**
1. Select an available device from the right panel
2. Click "Connect" to send a connection request
3. Wait for the other device to accept/reject
4. Connected devices appear in "My Connections"

### **4. Managing Connections**
1. View all your connections in the bottom panel
2. See connection status (Pending/Connected/Rejected)
3. Disconnect from devices when needed
4. Send PDFs to connected Android devices

### **5. PDF Workflow**
1. Select a connected Android device
2. Click "Send PDF"
3. Choose PDF file to send for signing
4. Monitor document status through the system

## Configuration

### **Broker URL**
Default: `http://localhost:8000`

To change the broker URL, modify the `SignikBrokerService` constructor in `MainForm.cs`:

```csharp
_brokerService = new SignikBrokerService("http://your-broker-url:port");
```

### **Refresh Intervals**
- **Device Data**: 5 seconds
- **Heartbeat**: 10 seconds

Modify in `MainForm.cs` constructor:

```csharp
_refreshTimer.Interval = 5000; // 5 seconds
_heartbeatTimer.Interval = 10000; // 10 seconds
```

## Architecture

### **Components**
- **MainForm.cs**: Primary UI and orchestration
- **Models/Device.cs**: Device and connection data models
- **Services/SignikBrokerService.cs**: Broker communication service

### **Communication Flow**
1. **HTTP REST API**: Device registration, connection management
2. **WebSocket**: Real-time messaging and notifications
3. **Heartbeat System**: Device online status monitoring

### **Data Models**
- **Device**: ID, Name, Type, IP, Online Status
- **DeviceConnection**: Connection relationships and status
- **SignikMessage**: WebSocket message format

## Troubleshooting

### **Connection Issues**
- Ensure Signik Broker is running on the specified URL
- Check firewall settings for HTTP/WebSocket connections
- Verify network connectivity between devices

### **Registration Failures**
- Confirm broker is accessible at the configured URL
- Check if device name conflicts exist
- Verify IP address detection is working

### **WebSocket Problems**
- Restart the application if WebSocket connection fails
- Check broker logs for connection errors
- Ensure WebSocket ports are not blocked

## API Integration

The application integrates with these Signik Broker endpoints:

- `POST /register_device` - Device registration
- `GET /devices` - All devices
- `GET /devices/online` - Online devices only
- `POST /devices/{id}/connect` - Initiate connection
- `GET /devices/{id}/connections` - Device connections
- `PUT /connections/{id}` - Update connection status
- `POST /heartbeat/{id}` - Send heartbeat
- `WebSocket /ws/{id}` - Real-time messaging

## Development

### **Adding Features**
1. Extend models in `Models/` directory
2. Add service methods in `SignikBrokerService`
3. Update UI in `MainForm.cs`
4. Handle new WebSocket message types

### **Custom Styling**
Modify colors, fonts, and layouts in the `InitializeComponent()` method.

### **Error Handling**
All network operations include try-catch blocks with user-friendly error messages.

## License

Part of the Signik Document Signing System. 