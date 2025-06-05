import '../models/signik_device.dart';
import '../models/signik_document.dart';
import '../models/device_connection.dart';
import 'api/api_client.dart';
import 'api/device_api.dart';
import 'api/document_api.dart';

/// Refactored broker service with better separation of concerns
class BrokerService {
  final String brokerUrl;
  final ApiClient _apiClient;
  final DeviceApi _deviceApi;
  final DocumentApi _documentApi;

  // Device registration state
  String? _deviceId;
  String? _deviceName;
  DeviceType? _deviceType;

  BrokerService({required this.brokerUrl})
      : _apiClient = ApiClient(baseUrl: brokerUrl),
        _deviceApi = DeviceApi(apiClient: ApiClient(baseUrl: brokerUrl)),
        _documentApi = DocumentApi(apiClient: ApiClient(baseUrl: brokerUrl));

  // Getters for device info
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  DeviceType? get deviceType => _deviceType;
  bool get isRegistered => _deviceId != null;

  /// Register this device with the broker
  Future<String> registerDevice(String deviceName, DeviceType deviceType) async {
    try {
      final result = await _deviceApi.registerDevice(
        deviceName: deviceName,
        deviceType: deviceType,
      );

      // Store device info
      _deviceId = result.deviceId;
      _deviceName = deviceName;
      _deviceType = deviceType;

      return result.deviceId;
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to register device',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Send heartbeat to keep device online
  Future<void> sendHeartbeat() async {
    if (!isRegistered) {
      throw BrokerException('Device not registered');
    }

    try {
      await _deviceApi.sendHeartbeat(_deviceId!);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to send heartbeat',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get list of registered devices
  Future<List<SignikDevice>> getDevices({DeviceType? deviceType}) async {
    try {
      return await _deviceApi.getDevices(deviceType: deviceType);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to get devices',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get list of online devices only
  Future<List<SignikDevice>> getOnlineDevices({DeviceType? deviceType}) async {
    try {
      return await _deviceApi.getOnlineDevices(deviceType: deviceType);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to get online devices',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Enqueue a document for signing
  Future<String> enqueueDocument(
    String name,
    String windowsDeviceId, {
    List<int>? pdfData,
  }) async {
    try {
      return await _documentApi.enqueueDocument(
        name: name,
        windowsDeviceId: windowsDeviceId,
        pdfData: pdfData,
      );
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to enqueue document',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get list of documents
  Future<List<SignikDocument>> getDocuments({
    SignikDocumentStatus? status,
  }) async {
    try {
      return await _documentApi.getDocuments(status: status);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to get documents',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Connect to another device
  Future<String> connectToDevice(String targetDeviceId) async {
    if (!isRegistered) {
      throw BrokerException('Device not registered');
    }

    try {
      return await _deviceApi.connectToDevice(
        sourceDeviceId: _deviceId!,
        targetDeviceId: targetDeviceId,
      );
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to connect to device',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get connections for this device
  Future<List<DeviceConnection>> getMyConnections() async {
    if (!isRegistered) {
      throw BrokerException('Device not registered');
    }

    try {
      return await _deviceApi.getDeviceConnections(_deviceId!);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to get connections',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Update connection status
  Future<void> updateConnectionStatus(
    String connectionId,
    ConnectionStatus status,
  ) async {
    try {
      await _deviceApi.updateConnectionStatus(
        connectionId: connectionId,
        status: status,
      );
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to update connection status',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get all connections (admin function)
  Future<List<DeviceConnection>> getAllConnections({
    ConnectionStatus? status,
  }) async {
    try {
      return await _deviceApi.getAllConnections(status: status);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to get all connections',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Delete a connection
  Future<void> deleteConnection(String connectionId) async {
    try {
      await _deviceApi.deleteConnection(connectionId);
    } on ApiException catch (e) {
      throw BrokerException(
        'Failed to delete connection',
        statusCode: e.statusCode,
        details: e.message,
      );
    }
  }

  /// Get WebSocket URL for this device
  String getWebSocketUrl() {
    if (!isRegistered) {
      throw BrokerException('Device not registered');
    }
    return brokerUrl.replaceFirst('http', 'ws') + '/ws/$_deviceId';
  }

  /// Dispose resources
  void dispose() {
    _apiClient.dispose();
  }
}

/// Broker-specific exception
class BrokerException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  BrokerException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    final buffer = StringBuffer('BrokerException: $message');
    if (statusCode != null) {
      buffer.write(' (Status: $statusCode)');
    }
    if (details != null) {
      buffer.write(' - $details');
    }
    return buffer.toString();
  }
}