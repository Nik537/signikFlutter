import 'dart:convert';
import 'dart:io';
import '../../models/signik_device.dart';
import '../../models/device_connection.dart';
import 'api_client.dart';

/// API service for device-related operations
class DeviceApi {
  final ApiClient _apiClient;

  DeviceApi({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Register a device
  Future<DeviceRegistrationResult> registerDevice({
    required String deviceName,
    required DeviceType deviceType,
  }) async {
    final ipAddress = await _getLocalIpAddress();

    final response = await _apiClient.post('/register_device', body: {
      'device_name': deviceName,
      'device_type': deviceType == DeviceType.windows ? 'windows' : 'android',
      'ip_address': ipAddress,
    });

    return DeviceRegistrationResult(
      deviceId: response['device_id'],
      message: response['message'],
      isUpdate: response['is_update'] ?? false,
    );
  }

  /// Send heartbeat
  Future<void> sendHeartbeat(String deviceId) async {
    await _apiClient.post('/heartbeat/$deviceId');
  }

  /// Get all devices
  Future<List<SignikDevice>> getDevices({DeviceType? deviceType}) async {
    final queryParams = <String, String>{};
    if (deviceType != null) {
      queryParams['device_type'] =
          deviceType == DeviceType.windows ? 'windows' : 'android';
    }

    final response = await _apiClient.get('/devices', queryParams: queryParams);
    final devices = response['devices'] as List<dynamic>;
    return devices.map((json) => SignikDevice.fromJson(json)).toList();
  }

  /// Get online devices only
  Future<List<SignikDevice>> getOnlineDevices({DeviceType? deviceType}) async {
    final queryParams = <String, String>{};
    if (deviceType != null) {
      queryParams['device_type'] =
          deviceType == DeviceType.windows ? 'windows' : 'android';
    }

    final response =
        await _apiClient.get('/devices/online', queryParams: queryParams);
    final devices = response['devices'] as List<dynamic>;
    return devices.map((json) => SignikDevice.fromJson(json)).toList();
  }

  /// Connect to another device
  Future<String> connectToDevice({
    required String sourceDeviceId,
    required String targetDeviceId,
  }) async {
    final response = await _apiClient.post(
      '/devices/$sourceDeviceId/connect',
      body: {'target_device_id': targetDeviceId},
    );
    return response['connection_id'];
  }

  /// Get connections for a device
  Future<List<DeviceConnection>> getDeviceConnections(String deviceId) async {
    final response = await _apiClient.get('/devices/$deviceId/connections');
    final connections = response['connections'] as List<dynamic>;
    return connections.map((json) => DeviceConnection.fromJson(json)).toList();
  }

  /// Update connection status
  Future<void> updateConnectionStatus({
    required String connectionId,
    required ConnectionStatus status,
  }) async {
    await _apiClient.put(
      '/connections/$connectionId',
      body: {'status': connectionStatusToString(status)},
    );
  }

  /// Get all connections
  Future<List<DeviceConnection>> getAllConnections({
    ConnectionStatus? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) {
      queryParams['status'] = connectionStatusToString(status);
    }

    final response =
        await _apiClient.get('/connections', queryParams: queryParams);
    final connections = response['connections'] as List<dynamic>;
    return connections.map((json) => DeviceConnection.fromJson(json)).toList();
  }

  /// Delete a connection
  Future<void> deleteConnection(String connectionId) async {
    await _apiClient.delete('/connections/$connectionId');
  }

  /// Get local IP address
  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return '127.0.0.1';
    } catch (e) {
      return '127.0.0.1';
    }
  }

  /// Convert ConnectionStatus to string
  String connectionStatusToString(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.pending:
        return 'pending';
      case ConnectionStatus.connected:
        return 'connected';
      case ConnectionStatus.rejected:
        return 'rejected';
      case ConnectionStatus.disconnected:
        return 'disconnected';
    }
  }
}

/// Device registration result
class DeviceRegistrationResult {
  final String deviceId;
  final String message;
  final bool isUpdate;

  DeviceRegistrationResult({
    required this.deviceId,
    required this.message,
    required this.isUpdate,
  });
}