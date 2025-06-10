import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/signik_device.dart';
import '../models/signik_document.dart';
import '../core/constants.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/utils/network_utils.dart';
import 'dart:async';

/// Service for communicating with the Signik broker via HTTP REST API
class BrokerService {
  final String brokerUrl;
  String? _deviceId;
  String? _deviceName;
  DeviceType? _deviceType;

  BrokerService({required this.brokerUrl});

  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  DeviceType? get deviceType => _deviceType;

  /// Register this device with the broker
  Future<String> registerDevice(String deviceName, DeviceType deviceType) async {
    try {
      final ipAddress = await _getLocalIpAddress();
      
      final response = await http.post(
        Uri.parse('$brokerUrl/register_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_name': deviceName,
          'device_type': deviceType == DeviceType.windows ? 'windows' : 'android',
          'ip_address': ipAddress,
        }),
      ).timeout(AppConstants.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _deviceId = data['device_id'];
        _deviceName = deviceName;
        _deviceType = deviceType;
        return _deviceId!;
      } else {
        throw NetworkException(
          'Failed to register device: ${response.body}',
          details: 'Status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw NetworkException('Unable to connect to broker at $brokerUrl');
    } on TimeoutException {
      throw NetworkException('Connection timeout while registering device');
    } catch (e) {
      if (e is SignikException) rethrow;
      throw NetworkException('Unexpected error during device registration', originalError: e);
    }
  }

  /// Send heartbeat to keep device online
  Future<void> sendHeartbeat() async {
    if (_deviceId == null) {
      throw ValidationException('Cannot send heartbeat: device not registered');
    }

    try {
      final response = await http.post(
        Uri.parse('$brokerUrl/heartbeat/$_deviceId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(AppConstants.heartbeatTimeout);

      if (response.statusCode != 200) {
        throw NetworkException(
          'Failed to send heartbeat: ${response.body}',
          details: 'Status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw NetworkException('Lost connection to broker');
    } on TimeoutException {
      throw NetworkException('Heartbeat timeout');
    } catch (e) {
      if (e is SignikException) rethrow;
      throw NetworkException('Unexpected error during heartbeat', originalError: e);
    }
  }

  /// Get list of registered devices
  Future<List<SignikDevice>> getDevices({DeviceType? deviceType}) async {
    try {
      String url = '$brokerUrl/devices';
      if (deviceType != null) {
        final typeStr = deviceType == DeviceType.windows ? 'windows' : 'android';
        url += '?device_type=$typeStr';
      }

      final response = await http.get(Uri.parse(url))
          .timeout(AppConstants.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> devicesJson = data['devices'];
        return devicesJson.map((json) => SignikDevice.fromJson(json)).toList();
      } else {
        throw NetworkException(
          'Failed to get devices: ${response.body}',
          details: 'Status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw NetworkException('Unable to reach broker');
    } on FormatException {
      throw NetworkException('Invalid response format from broker');
    } catch (e) {
      if (e is SignikException) rethrow;
      throw NetworkException('Failed to fetch devices', originalError: e);
    }
  }

  /// Enqueue a document for signing
  Future<String> enqueueDocument(String name, String windowsDeviceId, {List<int>? pdfData}) async {
    if (name.isEmpty) {
      throw ValidationException('Document name cannot be empty');
    }
    if (windowsDeviceId.isEmpty) {
      throw ValidationException('Windows device ID cannot be empty');
    }

    try {
      final response = await http.post(
        Uri.parse('$brokerUrl/enqueue_doc'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'windows_device_id': windowsDeviceId,
          if (pdfData != null) 'pdf_data': base64Encode(pdfData),
        }),
      ).timeout(AppConstants.documentUploadTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['doc_id'] ?? '';
      } else {
        throw NetworkException(
          'Failed to enqueue document: ${response.body}',
          details: 'Status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw NetworkException('Unable to connect to broker');
    } on TimeoutException {
      throw NetworkException('Document upload timeout');
    } catch (e) {
      if (e is SignikException) rethrow;
      throw NetworkException('Failed to enqueue document', originalError: e);
    }
  }

  /// Get list of documents
  Future<List<SignikDocument>> getDocuments({SignikDocumentStatus? status}) async {
    try {
      String url = '$brokerUrl/documents';
      if (status != null) {
        final statusStr = _documentStatusToString(status);
        url += '?status=$statusStr';
      }

      final response = await http.get(Uri.parse(url))
          .timeout(AppConstants.networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> documentsJson = data['documents'];
        return documentsJson.map((json) => SignikDocument.fromJson(json)).toList();
      } else {
        throw NetworkException(
          'Failed to get documents: ${response.body}',
          details: 'Status code: ${response.statusCode}',
        );
      }
    } on SocketException {
      throw NetworkException('Unable to reach broker');
    } on FormatException {
      throw NetworkException('Invalid document data from broker');
    } catch (e) {
      if (e is SignikException) rethrow;
      throw NetworkException('Failed to fetch documents', originalError: e);
    }
  }

  /// Get WebSocket URL for this device
  String getWebSocketUrl() {
    if (_deviceId == null) {
      throw ValidationException('Cannot get WebSocket URL: device not registered');
    }
    return NetworkUtils.httpToWebSocket(brokerUrl) + '/ws/$_deviceId';
  }

  /// Get the local IP address of this device
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
      return AppConstants.defaultLocalIp;
    } catch (e) {
      print('Failed to get local IP address: $e');
      return AppConstants.defaultLocalIp;
    }
  }

  /// Convert document status enum to string for API calls
  String _documentStatusToString(SignikDocumentStatus status) {
    switch (status) {
      case SignikDocumentStatus.queued:
        return 'queued';
      case SignikDocumentStatus.sent:
        return 'sent';
      case SignikDocumentStatus.signed:
        return 'signed';
      case SignikDocumentStatus.declined:
        return 'declined';
      case SignikDocumentStatus.deferred:
        return 'deferred';
      case SignikDocumentStatus.delivered:
        return 'delivered';
      default:
        return 'error';
    }
  }
} 