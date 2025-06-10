import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'websocket_service.dart';
import 'broker_service.dart';
import 'heartbeat_service.dart';
import 'app_config.dart';
import '../models/signik_device.dart';
import '../models/signik_message.dart';

class ConnectionManager extends ChangeNotifier {
  WebSocketService? _webSocketService;
  BrokerService? _brokerService;
  HeartbeatService? _heartbeatService;
  
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _messageController = StreamController<SignikMessage>.broadcast();
  final _rawDataController = StreamController<Uint8List>.broadcast();
  
  Stream<ConnectionState> get connectionState => _connectionStateController.stream;
  Stream<SignikMessage> get messages => _messageController.stream;
  Stream<Uint8List> get rawData => _rawDataController.stream;
  
  ConnectionState _currentState = ConnectionState.disconnected;
  
  ConnectionManager() {
    _webSocketService = WebSocketService();
    _brokerService = BrokerService(brokerUrl: AppConfig.brokerUrl);
  }

  Future<void> connect({String? deviceName}) async {
    try {
      _updateState(ConnectionState.connecting);
      
      // Use provided device name or generate default
      final name = deviceName ?? 
        (Platform.isWindows ? 'Windows PC ${DateTime.now().millisecondsSinceEpoch}' : 
         'Android Tablet ${DateTime.now().millisecondsSinceEpoch}');
      
      // Register device with broker
      final deviceType = Platform.isWindows ? DeviceType.windows : DeviceType.android;
      final deviceId = await _brokerService!.registerDevice(name, deviceType);
      
      print('Registered with broker as device: $deviceId');
      
      // Start heartbeat service
      _heartbeatService = HeartbeatService(_brokerService!);
      _heartbeatService!.start();
      
      // Connect WebSocket
      final wsUrl = _brokerService!.getWebSocketUrl();
      await _webSocketService!.connect(wsUrl);
      
      // Forward messages and raw data
      _webSocketService!.onMessage.listen((data) {
        if (data is SignikMessage) {
          _messageController.add(data);
        } else if (data is Uint8List) {
          _rawDataController.add(data);
        }
      });
      
      // Monitor connection
      _webSocketService!.onConnection.listen((isConnected) {
        _updateState(isConnected ? ConnectionState.connected : ConnectionState.disconnected);
      });
      
      _updateState(ConnectionState.connected);
    } catch (e) {
      _updateState(ConnectionState.error);
      rethrow;
    }
  }

  Future<void> sendMessage(SignikMessage message) async {
    // Don't override target deviceId if it's already set (for routing)
    // Instead, preserve the target deviceId and add sender info separately
    final messageToSend = message.copyWith(
      // Only set deviceId if it's null (preserve target device ID for routing)
      deviceId: message.deviceId ?? _brokerService?.deviceId,
    );
    
    print('DEBUG: Sending message with deviceId: ${messageToSend.deviceId} (original: ${message.deviceId}, sender: ${_brokerService?.deviceId})');
    await _webSocketService?.sendData(messageToSend);
  }

  Future<void> sendRawData(List<int> data) async {
    await _webSocketService?.sendData(data);
  }

  Future<List<SignikDevice>> getOnlineDevices({DeviceType? deviceType}) async {
    if (_brokerService != null) {
      final filterType = deviceType ?? (Platform.isWindows ? DeviceType.android : DeviceType.windows);
      return await _brokerService!.getDevices(deviceType: filterType);
    }
    return [];
  }

  Future<String> enqueueDocument(String name, {List<int>? pdfData}) async {
    if (_brokerService == null || _brokerService!.deviceId == null) {
      throw Exception('Not connected to broker');
    }
    
    return await _brokerService!.enqueueDocument(name, _brokerService!.deviceId!, pdfData: pdfData);
  }

  String? get deviceId => _brokerService?.deviceId;
  
  bool get isConnected => _currentState == ConnectionState.connected;

  void _updateState(ConnectionState newState) {
    _currentState = newState;
    _connectionStateController.add(newState);
  }

  Future<void> disconnect() async {
    _heartbeatService?.stop();
    await _webSocketService?.dispose();
    await _connectionStateController.close();
    await _messageController.close();
    await _rawDataController.close();
    _updateState(ConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
  }

  // Test connection to a specific device
  Future<void> testDeviceConnection(String deviceId) async {
    try {
      // Send a heartbeat message to the device (using heartbeat instead of ping)
      final testMessage = SignikMessage(
        type: SignikMessageType.heartbeat,
        deviceId: deviceId,
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
      
      await sendMessage(testMessage);
      
      // Wait for response (implement timeout logic if needed)
      await Future.delayed(const Duration(seconds: 2));
      
      // For now, we'll assume success if no exception is thrown
      // In a real implementation, you'd wait for a pong response
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  // Get all devices (for device management UI)
  List<SignikDevice> _devices = [];
  List<SignikDevice> get devices => _devices;
  SignikDevice? get currentDevice => _devices.firstWhere(
    (d) => d.id == deviceId,
    orElse: () => SignikDevice(
      id: deviceId ?? '',
      name: 'Current Device',
      deviceType: Platform.isWindows ? DeviceType.windows : DeviceType.android,
      lastHeartbeat: DateTime.now(),
      isOnline: true,
    ),
  );
  
  // Periodically refresh device list
  Timer? _deviceRefreshTimer;
  
  void startDeviceRefresh() {
    _deviceRefreshTimer?.cancel();
    _deviceRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await refreshDevices();
    });
    // Initial refresh
    refreshDevices();
  }
  
  void stopDeviceRefresh() {
    _deviceRefreshTimer?.cancel();
  }
  
  Future<void> refreshDevices() async {
    try {
      if (_brokerService != null) {
        // Get all devices (both Windows and Android)
        final allDevices = await _brokerService!.getDevices();
        _devices = allDevices;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing devices: $e');
    }
  }
}

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
} 