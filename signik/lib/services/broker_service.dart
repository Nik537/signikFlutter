import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/signik_device.dart';
import '../models/signik_document.dart';

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
    final ipAddress = await _getLocalIpAddress();
    
    final response = await http.post(
      Uri.parse('$brokerUrl/register_device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_name': deviceName,
        'device_type': deviceType == DeviceType.windows ? 'windows' : 'android',
        'ip_address': ipAddress,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _deviceId = data['device_id'];
      _deviceName = deviceName;
      _deviceType = deviceType;
      return _deviceId!;
    } else {
      throw Exception('Failed to register device: ${response.body}');
    }
  }

  /// Send heartbeat to keep device online
  Future<void> sendHeartbeat() async {
    if (_deviceId == null) return;

    final response = await http.post(
      Uri.parse('$brokerUrl/heartbeat/$_deviceId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send heartbeat: ${response.body}');
    }
  }

  /// Get list of registered devices
  Future<List<SignikDevice>> getDevices({DeviceType? deviceType}) async {
    String url = '$brokerUrl/devices';
    if (deviceType != null) {
      final typeStr = deviceType == DeviceType.windows ? 'windows' : 'android';
      url += '?device_type=$typeStr';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> devicesJson = data['devices'];
      return devicesJson.map((json) => SignikDevice.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get devices: ${response.body}');
    }
  }

  /// Enqueue a document for signing
  Future<String> enqueueDocument(String name, String windowsDeviceId, {List<int>? pdfData}) async {
    final response = await http.post(
      Uri.parse('$brokerUrl/enqueue_doc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'windows_device_id': windowsDeviceId,
        if (pdfData != null) 'pdf_data': base64Encode(pdfData),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['doc_id'];
    } else {
      throw Exception('Failed to enqueue document: ${response.body}');
    }
  }

  /// Get list of documents
  Future<List<SignikDocument>> getDocuments({SignikDocumentStatus? status}) async {
    String url = '$brokerUrl/documents';
    if (status != null) {
      final statusStr = _documentStatusToString(status);
      url += '?status=$statusStr';
    }

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> documentsJson = data['documents'];
      return documentsJson.map((json) => SignikDocument.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get documents: ${response.body}');
    }
  }

  /// Get WebSocket URL for this device
  String getWebSocketUrl() {
    if (_deviceId == null) {
      throw Exception('Device not registered');
    }
    return brokerUrl.replaceFirst('http', 'ws') + '/ws/$_deviceId';
  }

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