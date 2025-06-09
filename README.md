# Signik - Cross-Platform PDF Signing Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.2.3-blue.svg)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1-green.svg)](https://fastapi.tiangolo.com)

Signik is a real-time, cross-platform PDF signing solution that enables seamless document signing workflow between Windows desktop and Android mobile devices. The project aims to reach feature parity with TRON Sign, a production-grade signing system.

## 🎯 Project Vision

**Windows Workflow**: PDF management, device routing, signature review, and final document assembly  
**Android Workflow**: PDF reception, signature capture, and approval waiting  
**Broker Coordination**: Multi-device routing, state management, and real-time communication

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Windows PC    │    │  Signik Broker  │    │ Android Tablet  │
│                 │    │   (FastAPI)     │    │                 │
│ • PDF Management│◄──►│ • Device Registry│◄──►│ • Signature UI  │
│ • Device Routing│    │ • Message Router │    │ • PDF Preview   │
│ • Review Dialog │    │ • State Machine │    │ • Status Panel  │
│ • Final Assembly│    │ • WebSocket Hub │    │ • Offline Cache │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## ✅ What's Implemented (Step 1 Complete)

### 🔧 **Broker Service** (`signik_broker/`)
- **Device Registration**: Windows PCs and Android tablets register with unique IDs
- **Document Queue**: Centralized queue with full status lifecycle
- **Real-time Routing**: WebSocket message routing between devices  
- **Heartbeat Monitoring**: Automatic offline detection (30s timeout)
- **REST API**: Full CRUD operations with filtering
- **Status Machine**: `queued → sent → signed/declined → delivered`

### 📱 **Enhanced Flutter Models** (`signik/lib/models/`)
- **Document Model**: Extended with broker-compatible status enum and fields
- **Message Protocol**: Enhanced with `docId`, `deviceId`, and new message types
- **Device Model**: Support for multi-device registry and online status

### 🔌 **Integration Services** (`signik/lib/services/`)
- **Broker Service**: HTTP client for registration, queuing, and device management
- **Heartbeat Service**: Automatic periodic heartbeat with configurable intervals
- **WebSocket Service**: Updated to work with broker routing (existing)

### 🧪 **Testing & Validation**
- **Comprehensive Test Suite**: `test_broker.py` validates all endpoints and workflows
- **Full Workflow Simulation**: End-to-end document signing simulation
- **Real-time Monitoring**: Device status and message routing verification

## 🚀 Quick Start

### 1. Start the Broker
```bash
cd signik_broker/
pip install -r requirements.txt
python main.py
# Broker runs on http://localhost:8000
# API docs at http://localhost:8000/docs
```

### 2. Test the Broker (Optional)
```bash
pip install requests websockets  # For test dependencies
python test_broker.py
# Runs comprehensive functionality tests
```

### 3. Run Flutter Apps
```bash
cd signik/
flutter pub get
flutter run -d windows    # For Windows
flutter run -d android    # For Android
```

## 📊 Progress Towards TRON Sign Parity

| Feature | Current Status | Priority | Complexity |
|---------|----------------|----------|------------|
| ✅ **Multi-device Broker** | ✅ Complete | P0 | High |
| 🔄 **Document State Machine** | 🔄 Partial | P0 | Medium |
| 🔄 **Device Registry & Routing** | 🔄 Basic | P0 | Medium |
| ❌ **Database Persistence** | ❌ Todo | P1 | Medium |
| ❌ **Deferred Signature Flow** | ❌ Todo | P1 | Low |
| ❌ **Multi-PDF Batching** | ❌ Todo | P1 | Medium |
| ❌ **Offline Sync (Android)** | ❌ Todo | P2 | High |
| ❌ **Authentication & Roles** | ❌ Todo | P2 | Medium |
| ❌ **Audit Trail & Export** | ❌ Todo | P3 | Low |

## 🛠️ Next Development Steps

### **Step 2: Enhanced Document State Machine** (2-3 days)
```bash
# Ready-to-use Cursor prompts:
```
> "Add SQLite database support to the broker using SQLAlchemy. Create Document, Device, and AuditEvent tables with proper relationships. Migrate from in-memory storage."

> "Create a document queue UI widget for Windows using DataTable with column filters for status, date, and device. Support sorting and real-time updates via WebSocket."

### **Step 3: Deferred Signature Flow** (1-2 days)
> "Add 'Defer Signature' button to Android UI and implement deferSignature/retrieveDeferred message types. Update broker to handle deferred status and retrieval."

### **Step 4: Multi-PDF Support** (2-3 days)
> "Implement SignBatch model that contains multiple PDFs. Update Android UI to show batch carousel. Modify broker to handle batch workflows."

### **Step 5: Offline Capabilities** (3-4 days)
> "Add Hive local storage to Android app. Implement background sync service that retries uploads when connectivity returns. Cache signatures and PDFs locally."

### **Step 6: Authentication** (2-3 days)
> "Add JWT authentication to broker with roles (admin, tablet, driver). Implement login screens and secure WebSocket connections with token validation."

### **Step 7: Audit & Export** (1-2 days)
> "Add audit logging for all state changes. Implement CSV export functionality with date/device filtering for compliance reporting."

## 📂 Project Structure

```
SignikFlutter/
├── signik/                     # Flutter Application
│   ├── lib/
│   │   ├── models/            # Data models (Document, Message, Device)
│   │   ├── services/          # Business logic (Broker, WebSocket, Heartbeat)
│   │   ├── ui/                # Platform-specific screens
│   │   └── widgets/           # Reusable UI components
│   └── pubspec.yaml           # Flutter dependencies
│
├── signik_broker/             # FastAPI Broker Service  
│   ├── main.py               # Broker server with full API
│   ├── requirements.txt      # Python dependencies
│   └── README.md            # Broker documentation
│
├── test_broker.py            # Comprehensive test suite
└── README.md                # This file
```

## 🔧 Key Technologies

- **Flutter 3.2.3**: Cross-platform UI framework
- **FastAPI**: High-performance Python web framework  
- **WebSocket**: Real-time bidirectional communication
- **SQLAlchemy**: Database ORM (planned)
- **JWT**: Authentication tokens (planned)
- **Hive**: Local storage for offline support (planned)

## 🌟 What Makes Signik Powerful

1. **Real-time Multi-device**: One Windows PC can route to multiple Android tablets
2. **Robust State Management**: Complete document lifecycle with audit trail
3. **Offline-first Mobile**: Android works without constant connectivity  
4. **Scalable Architecture**: Broker enables cloud deployment and load balancing
5. **TRON Sign Compatible**: Following production patterns for enterprise deployment

## 🤝 Contributing

Each development step has ready-to-use Cursor AI prompts. Fork the repo, pick a step from the roadmap, and paste the corresponding prompt into Cursor for guided implementation.

## 📝 License

MIT License - see LICENSE file for details.

---

**Ready to continue development?** Use the Cursor prompts from the roadmap above to implement the next features systematically. Each step builds on the previous one, ensuring a stable development path toward full TRON Sign parity. 