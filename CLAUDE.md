# Signik Project Documentation

## Overview
Signik is a cross-platform PDF signing solution that enables real-time document signing workflows between Windows desktop computers and Android tablets. Built with Flutter for clients and FastAPI for the broker service.

## Architecture

### Components
1. **Windows Client** (Flutter Desktop) - PDF management, device routing, signature review
2. **Android Client** (Flutter Mobile) - PDF reception, signature capture, approval workflow  
3. **Signik Broker** (FastAPI/Python) - Central WebSocket hub, device registry, document state management

### Technology Stack
- Flutter 3.2.3 (Cross-platform UI)
- FastAPI (Python web framework)
- WebSocket (Real-time communication)
- Syncfusion Flutter PDF (PDF manipulation)
- HTTP/REST (Device registration, CRUD operations)

## Key Services

### Flutter Services (lib/services/)
- **ConnectionManager**: Orchestrates broker connection and communication
- **BrokerService**: HTTP client for REST API operations
- **WebSocketService**: Real-time bidirectional messaging
- **FileService**: Windows file watching and management
- **PDFService**: PDF manipulation and signature embedding
- **HeartbeatService**: Periodic connection heartbeat

### Broker Service (signik_broker/main.py)
- WebSocket server on port 8000
- Device registration and heartbeat monitoring (30s timeout)
- Document queue with state machine: queued → sent → signed/declined → delivered
- REST endpoints for device and document management

## Data Models

### SignikMessage
Protocol for device communication with types:
- sendStart, signaturePreview, signatureAccepted/Declined
- documentReceived, documentDelivered, error

### SignikDocument
Document lifecycle tracking:
- Status states, device assignments, timestamps
- Source (Windows) and target (Android) device IDs

### SignikDevice
Device registry:
- Type (Windows/Android), online status, heartbeat tracking

## Development Commands

### Flutter
```bash
# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d <device-id>

# Build Windows
flutter build windows

# Build Android APK
flutter build apk
```

### Broker
```bash
# Start broker
cd signik_broker
python main.py

# Run tests
python test_broker.py
```

## Important Notes

### Testing
- Always run `flutter analyze` before committing
- Test broker connectivity with `test_broker.py`
- Verify WebSocket communication between devices

### File Paths
- Windows: Uses absolute paths for file operations
- Android: Works with temporary file storage
- Broker: Handles binary data transfer for PDFs

### Common Issues
1. **WebSocket Connection**: Ensure broker is running on correct IP/port
2. **Device Registration**: Check heartbeat service is active
3. **PDF Transfer**: Verify file size limits and binary encoding

## Workflow

1. Windows PC registers and watches for PDFs
2. Android tablets register and wait
3. User drops PDF on Windows app
4. Device selection dialog appears
5. PDF sent to Android via broker
6. Android captures signature
7. Signature preview sent to Windows
8. Windows accepts/declines
9. Final signed PDF saved

## Future Features (Roadmap)
- P1: Database persistence, batch processing
- P2: Offline sync, authentication
- P3: Audit trails, cloud deployment