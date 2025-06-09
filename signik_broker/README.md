# Signik Broker Service

A FastAPI-based broker service that enables multi-device communication for the Signik PDF signing application.

## Features

- **Device Registration**: Windows PCs and Android tablets register with unique IDs
- **Document Queue Management**: Centralized queue with status tracking
- **Real-time Communication**: WebSocket routing between devices
- **Device Heartbeat Monitoring**: Automatic detection of offline devices
- **REST API**: Full CRUD operations for devices and documents

## Quick Start

### Prerequisites
- Python 3.8+
- pip

### Installation
```bash
# Install dependencies
pip install -r requirements.txt

# Run the broker
python main.py
```

The broker will start on `http://localhost:8000`

### API Documentation
Once running, visit `http://localhost:8000/docs` for interactive API documentation.

## API Endpoints

### Device Management
- `POST /register_device` - Register a new Windows PC or Android tablet
- `GET /devices` - List all registered devices (filter by type)
- `POST /heartbeat/{device_id}` - Send heartbeat to keep device online

### Document Management
- `POST /enqueue_doc` - Add document to signing queue
- `GET /documents` - List documents (filter by status)

### WebSocket
- `WS /ws/{device_id}` - Real-time communication channel

## Document Status Flow
1. `queued` - Document added to queue
2. `sent` - PDF sent to Android device
3. `signed` - Signature received and accepted
4. `declined` - Signature rejected, needs re-signing
5. `deferred` - Signature postponed
6. `delivered` - Final signed PDF completed

## Integration with Flutter Apps

The broker is designed to work seamlessly with your existing Signik Windows and Android apps. The apps will need to:

1. Register on startup: `POST /register_device`
2. Connect via WebSocket: `WS /ws/{device_id}`
3. Send periodic heartbeats: `POST /heartbeat/{device_id}`

## Next Steps

- Add SQL database persistence (SQLAlchemy + PostgreSQL)
- Implement JWT authentication
- Add audit logging
- Support multi-PDF batches
- Add offline sync capabilities 