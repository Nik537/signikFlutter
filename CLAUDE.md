# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Commands

### Flutter App (signik/)
```bash
# Install dependencies
flutter pub get

# Run application
flutter run -d windows    # Windows desktop
flutter run -d android    # Android device/emulator

# Build release versions
flutter build windows
flutter build apk

# Run tests
flutter test

# Check code quality
flutter analyze
```

### Python Broker (signik_broker/)
```bash
# Install dependencies
pip install -r requirements.txt

# Start broker server
python main.py
# Or use: start_broker.bat

# Run integration tests
python test_broker.py

# Access API documentation
# http://localhost:8000/docs
```

### Windows Forms App (SignikWindowsApp/)
```bash
# Build and run
dotnet run
# Or use: run.bat

# Build only
dotnet build

# Restore packages
dotnet restore
```

## Architecture Overview

### System Design
The project implements a **hub-and-spoke architecture** where the FastAPI broker serves as the central communication hub between Windows PCs and Android devices:

```
Windows PC ←→ Broker (FastAPI) ←→ Android Device
     ↑              ↑                    ↑
     └── HTTP/WS ───┴──── HTTP/WS ──────┘
```

### Communication Flow
1. **Device Registration**: HTTP POST to `/api/devices/register` with device info
2. **WebSocket Connection**: Connect to `/ws/{device_id}` for real-time messaging
3. **Message Routing**: Broker routes messages based on document ID and device connections
4. **Binary Transfer**: PDF files sent as binary WebSocket frames with metadata

### Key Services and Their Responsibilities

#### Broker Service (`signik_broker/main.py`)
- Maintains device registry with deduplication (by name+type)
- Manages many-to-many device connections
- Routes messages between connected devices
- Tracks document lifecycle states
- Monitors device health via heartbeats

#### Flutter Services (`signik/lib/services/`)
- **BrokerService**: HTTP client for REST API operations
- **WebSocketService**: Handles real-time messaging and binary transfers
- **HeartbeatService**: Sends periodic heartbeats to maintain online status
- **ConnectionManager**: Manages device connection state and requests

#### Windows Services (`SignikWindowsApp/Services/`)
- **SignikBrokerService**: Complete broker integration with WebSocket support
- Handles connection requests/responses
- Manages real-time UI updates

### State Management

#### Document States
```
queued → sent → signed/declined → delivered
              ↘ deferred ↙
```

#### Connection States
```
pending → connected → disconnected
       ↘ rejected
```

### Platform-Specific Considerations
- Flutter app has separate UI implementations for Windows (`ui/windows/`) and Android (`ui/android/`)
- Windows Forms app uses DataGridView for device management UI
- Android app optimized for touch input and mobile screens

### Configuration Points
- **Broker URL**: Configured in `AppConfig.dart` and Windows app settings
- **Heartbeat Interval**: Default 10 seconds, configurable
- **UI Refresh Rate**: Default 5 seconds for real-time updates
- **WebSocket Timeout**: 30 seconds for device offline detection

### Testing Strategy
- **Unit Tests**: Basic widget tests in Flutter (`test/widget_test.dart`)
- **Integration Tests**: `test_broker.py` simulates complete signing workflow
- **Device Simulation**: `test_device_connections.py` creates multiple virtual devices
- **Manual Testing**: TestForm in Windows app for quick debugging

### Current Limitations (Step 1 Complete)
- In-memory storage (ready for SQLAlchemy migration)
- No authentication/authorization
- No offline sync for Android
- Single PDF support (no batching yet)
- No audit trail/export functionality

### Development Workflow
1. Always start the broker first
2. Devices auto-register on startup
3. Use broker API docs for debugging
4. Test with simulation scripts before real devices
5. Check heartbeat logs for connection issues

## Refactored Code Structure

### Python Broker (`signik_broker/`)
The broker has been refactored into modular components:
- **models.py**: All Pydantic models and enums
- **storage.py**: In-memory storage manager with async operations
- **websocket_manager.py**: WebSocket connection and message routing
- **api_routes.py**: API endpoint handlers
- **main.py**: FastAPI app setup and configuration

### Flutter Services (`signik/lib/services/`)
Services have been refactored for better separation of concerns:
- **api/**: HTTP API clients separated by domain (device_api.dart, document_api.dart)
- **websocket/**: Separate WebSocket client and server implementations
- **broker_service_refactored.dart**: Cleaner broker service with proper error handling
- **connection_manager_refactored.dart**: Improved connection management with streams

### Flutter UI Components (`signik/lib/ui/`)
UI has been modularized with reusable components:
- **base/**: Base classes for common functionality
- **components/**: Reusable UI widgets (ConnectionStatusWidget, PdfDropZone, DeviceListWidget)
- **windows/home_refactored.dart**: Cleaner Windows UI using composition

### Key Improvements
1. **Better Error Handling**: Custom exceptions and proper error propagation
2. **Async Operations**: Proper use of async/await throughout
3. **Type Safety**: Improved type hints and model validation
4. **Modularity**: Clear separation of concerns with single responsibility
5. **Reusability**: Common UI components extracted for reuse
6. **Logging**: Structured logging in Python broker
7. **Connection Management**: Automatic reconnection and state management