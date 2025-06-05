import 'package:flutter/material.dart';
import '../../services/connection_manager_refactored.dart';
import '../../services/broker_service_refactored.dart';
import '../../models/signik_device.dart';

/// Base home screen with common functionality for both platforms
abstract class BaseHomeScreen extends StatefulWidget {
  const BaseHomeScreen({super.key});
}

abstract class BaseHomeScreenState<T extends BaseHomeScreen> extends State<T> {
  late final BrokerService brokerService;
  late final ConnectionManager connectionManager;
  
  bool isConnected = false;
  String statusMessage = 'Initializing...';
  List<SignikDevice> onlineDevices = [];
  
  // Platform-specific configuration
  String get deviceName;
  DeviceType get deviceType;
  
  @override
  void initState() {
    super.initState();
    initializeServices();
  }
  
  /// Initialize services
  Future<void> initializeServices() async {
    try {
      // Create services
      brokerService = BrokerService(brokerUrl: getBrokerUrl());
      connectionManager = ConnectionManager(brokerService: brokerService);
      
      // Register device
      await brokerService.registerDevice(deviceName, deviceType);
      
      // Initialize connection manager
      await connectionManager.initialize();
      
      // Setup listeners
      setupListeners();
      
      // Initial refresh
      await refreshOnlineDevices();
      
      setState(() {
        isConnected = true;
        statusMessage = getConnectedMessage();
      });
    } catch (e) {
      setState(() {
        isConnected = false;
        statusMessage = 'Error: $e';
      });
      onInitializeError(e);
    }
  }
  
  /// Setup connection listeners
  void setupListeners() {
    // Connection state changes
    connectionManager.connectionState.listen((state) {
      setState(() {
        isConnected = state == ConnectionState.connected;
        statusMessage = getStatusMessage(state);
      });
      onConnectionStateChanged(state);
    });
    
    // Messages
    connectionManager.messages.listen(onMessage);
    
    // Binary data
    connectionManager.binaryData.listen(onBinaryData);
    
    // Connection requests
    connectionManager.connectionRequests.listen(onConnectionRequest);
    
    // Connection status updates
    connectionManager.connectionStatusUpdates.listen(onConnectionStatusUpdate);
  }
  
  /// Refresh online devices
  Future<void> refreshOnlineDevices() async {
    try {
      final targetType = deviceType == DeviceType.windows 
          ? DeviceType.android 
          : DeviceType.windows;
      
      final devices = await brokerService.getOnlineDevices(
        deviceType: targetType,
      );
      
      setState(() {
        onlineDevices = devices;
      });
      
      onDevicesRefreshed(devices);
    } catch (e) {
      onRefreshError(e);
    }
  }
  
  /// Get broker URL from config
  String getBrokerUrl() {
    // This should come from AppConfig or similar
    return 'http://localhost:8000';
  }
  
  /// Get status message for connection state
  String getStatusMessage(ConnectionState state) {
    switch (state) {
      case ConnectionState.disconnected:
        return 'Disconnected from broker';
      case ConnectionState.connecting:
        return 'Connecting to broker...';
      case ConnectionState.connected:
        return getConnectedMessage();
      case ConnectionState.reconnecting:
        return 'Reconnecting to broker...';
      case ConnectionState.error:
        return 'Connection error';
      case ConnectionState.failed:
        return 'Connection failed';
    }
  }
  
  /// Get connected message
  String getConnectedMessage() {
    return 'Connected to broker. ${onlineDevices.length} device(s) online';
  }
  
  // Platform-specific handlers (to be overridden)
  void onInitializeError(dynamic error) {}
  void onConnectionStateChanged(ConnectionState state) {}
  void onMessage(dynamic message) {}
  void onBinaryData(List<int> data) {}
  void onConnectionRequest(ConnectionRequest request) {}
  void onConnectionStatusUpdate(ConnectionStatusUpdate update) {}
  void onDevicesRefreshed(List<SignikDevice> devices) {}
  void onRefreshError(dynamic error) {}
  
  @override
  void dispose() {
    connectionManager.dispose();
    brokerService.dispose();
    super.dispose();
  }
}