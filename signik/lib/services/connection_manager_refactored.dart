import 'dart:async';
import '../models/signik_device.dart';
import '../models/signik_message.dart';
import '../models/device_connection.dart';
import 'broker_service_refactored.dart';
import 'websocket/websocket_client.dart';
import 'heartbeat_service.dart';

/// Manages device connections and real-time communication
class ConnectionManager {
  final BrokerService _brokerService;
  final WebSocketClient _wsClient;
  final HeartbeatService _heartbeatService;
  
  final _messageController = StreamController<SignikMessage>.broadcast();
  final _connectionRequestController = StreamController<ConnectionRequest>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatusUpdate>.broadcast();
  final _binaryDataController = StreamController<List<int>>.broadcast();
  
  Timer? _connectionCheckTimer;
  bool _disposed = false;

  ConnectionManager({
    required BrokerService brokerService,
    WebSocketClient? wsClient,
    HeartbeatService? heartbeatService,
  })  : _brokerService = brokerService,
        _wsClient = wsClient ?? WebSocketClient(),
        _heartbeatService = heartbeatService ?? HeartbeatService(brokerService: brokerService);

  // Stream getters
  Stream<SignikMessage> get messages => _messageController.stream;
  Stream<ConnectionRequest> get connectionRequests => _connectionRequestController.stream;
  Stream<ConnectionStatusUpdate> get connectionStatusUpdates => _connectionStatusController.stream;
  Stream<List<int>> get binaryData => _binaryDataController.stream;
  Stream<ConnectionState> get connectionState => _wsClient.connectionState;
  bool get isConnected => _wsClient.isConnected;

  /// Initialize connection manager
  Future<void> initialize() async {
    if (!_brokerService.isRegistered) {
      throw StateError('Device must be registered before initializing connections');
    }

    // Connect to WebSocket
    final wsUrl = _brokerService.getWebSocketUrl();
    await _wsClient.connect(wsUrl);

    // Start listening to WebSocket messages
    _wsClient.messages.listen(_handleWebSocketMessage);

    // Start heartbeat service
    _heartbeatService.start();

    // Start periodic connection check
    _startConnectionCheck();
  }

  /// Send a message
  Future<void> sendMessage(SignikMessage message) async {
    message.deviceId = _brokerService.deviceId;
    await _wsClient.sendMessage(message);
  }

  /// Send binary data
  Future<void> sendBinaryData(List<int> data) async {
    await _wsClient.sendBinary(data);
  }

  /// Request connection to a device
  Future<String> requestConnection(String targetDeviceId) async {
    try {
      final connectionId = await _brokerService.connectToDevice(targetDeviceId);
      return connectionId;
    } catch (e) {
      throw ConnectionException('Failed to request connection: $e');
    }
  }

  /// Accept a connection request
  Future<void> acceptConnection(String connectionId) async {
    try {
      await _brokerService.updateConnectionStatus(
        connectionId,
        ConnectionStatus.connected,
      );
    } catch (e) {
      throw ConnectionException('Failed to accept connection: $e');
    }
  }

  /// Reject a connection request
  Future<void> rejectConnection(String connectionId) async {
    try {
      await _brokerService.updateConnectionStatus(
        connectionId,
        ConnectionStatus.rejected,
      );
    } catch (e) {
      throw ConnectionException('Failed to reject connection: $e');
    }
  }

  /// Disconnect from a device
  Future<void> disconnect(String connectionId) async {
    try {
      await _brokerService.deleteConnection(connectionId);
    } catch (e) {
      throw ConnectionException('Failed to disconnect: $e');
    }
  }

  /// Get my connections
  Future<List<DeviceConnection>> getMyConnections() async {
    try {
      return await _brokerService.getMyConnections();
    } catch (e) {
      throw ConnectionException('Failed to get connections: $e');
    }
  }

  /// Get available devices for connection
  Future<List<SignikDevice>> getAvailableDevices() async {
    try {
      // Get online devices of opposite type
      final myType = _brokerService.deviceType;
      final targetType = myType == DeviceType.windows 
          ? DeviceType.android 
          : DeviceType.windows;
      
      final devices = await _brokerService.getOnlineDevices(
        deviceType: targetType,
      );
      
      // Filter out already connected devices
      final myConnections = await getMyConnections();
      final connectedIds = myConnections
          .where((c) => c.status == ConnectionStatus.connected)
          .map((c) => c.otherDevice?.id)
          .where((id) => id != null)
          .toSet();
      
      return devices.where((d) => !connectedIds.contains(d.id)).toList();
    } catch (e) {
      throw ConnectionException('Failed to get available devices: $e');
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(dynamic data) {
    if (data is SignikMessage) {
      _messageController.add(data);
    } else if (data is Map<String, dynamic>) {
      _handleJsonMessage(data);
    } else if (data is List<int>) {
      _binaryDataController.add(data);
    }
  }

  /// Handle JSON messages
  void _handleJsonMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    
    switch (type) {
      case 'connectionRequest':
        _handleConnectionRequest(json);
        break;
      case 'connectionStatusUpdate':
        _handleConnectionStatusUpdate(json);
        break;
      case 'connectionRemoved':
        _handleConnectionRemoved(json);
        break;
      default:
        // Try to parse as SignikMessage
        try {
          final message = SignikMessage.fromJson(json);
          _messageController.add(message);
        } catch (_) {
          // Unknown message type
        }
    }
  }

  /// Handle connection request
  void _handleConnectionRequest(Map<String, dynamic> json) {
    final connectionId = json['connection_id'] as String?;
    final fromDevice = json['from_device'] as Map<String, dynamic>?;
    
    if (connectionId != null && fromDevice != null) {
      final device = SignikDevice.fromJson(fromDevice);
      _connectionRequestController.add(ConnectionRequest(
        connectionId: connectionId,
        fromDevice: device,
      ));
    }
  }

  /// Handle connection status update
  void _handleConnectionStatusUpdate(Map<String, dynamic> json) {
    final connectionId = json['connection_id'] as String?;
    final statusStr = json['status'] as String?;
    
    if (connectionId != null && statusStr != null) {
      final status = _parseConnectionStatus(statusStr);
      if (status != null) {
        _connectionStatusController.add(ConnectionStatusUpdate(
          connectionId: connectionId,
          status: status,
        ));
      }
    }
  }

  /// Handle connection removed
  void _handleConnectionRemoved(Map<String, dynamic> json) {
    final connectionId = json['connection_id'] as String?;
    
    if (connectionId != null) {
      _connectionStatusController.add(ConnectionStatusUpdate(
        connectionId: connectionId,
        status: ConnectionStatus.disconnected,
      ));
    }
  }

  /// Parse connection status from string
  ConnectionStatus? _parseConnectionStatus(String status) {
    switch (status) {
      case 'pending':
        return ConnectionStatus.pending;
      case 'connected':
        return ConnectionStatus.connected;
      case 'rejected':
        return ConnectionStatus.rejected;
      case 'disconnected':
        return ConnectionStatus.disconnected;
      default:
        return null;
    }
  }

  /// Start periodic connection check
  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnections(),
    );
  }

  /// Check connection health
  Future<void> _checkConnections() async {
    if (_disposed) return;
    
    try {
      // Refresh connections from server
      await getMyConnections();
    } catch (_) {
      // Ignore errors in background check
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _disposed = true;
    _connectionCheckTimer?.cancel();
    _heartbeatService.stop();
    await _wsClient.dispose();
    await _messageController.close();
    await _connectionRequestController.close();
    await _connectionStatusController.close();
    await _binaryDataController.close();
  }
}

/// Connection request event
class ConnectionRequest {
  final String connectionId;
  final SignikDevice fromDevice;

  ConnectionRequest({
    required this.connectionId,
    required this.fromDevice,
  });
}

/// Connection status update event
class ConnectionStatusUpdate {
  final String connectionId;
  final ConnectionStatus status;

  ConnectionStatusUpdate({
    required this.connectionId,
    required this.status,
  });
}

/// Connection exception
class ConnectionException implements Exception {
  final String message;

  ConnectionException(this.message);

  @override
  String toString() => 'ConnectionException: $message';
}