import 'signik_device.dart';

enum ConnectionStatus {
  pending,
  connected,
  rejected,
  disconnected,
}

class DeviceConnection {
  final String id;
  final String windowsDeviceId;
  final String androidDeviceId;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String initiatedBy;
  final SignikDevice? otherDevice; // The device this connection is with

  DeviceConnection({
    required this.id,
    required this.windowsDeviceId,
    required this.androidDeviceId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.initiatedBy,
    this.otherDevice,
  });

  factory DeviceConnection.fromJson(Map<String, dynamic> json) {
    return DeviceConnection(
      id: json['id'] as String,
      windowsDeviceId: json['windows_device_id'] as String,
      androidDeviceId: json['android_device_id'] as String,
      status: _connectionStatusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      initiatedBy: json['initiated_by'] as String,
      otherDevice: json['other_device'] != null 
          ? SignikDevice.fromJson(json['other_device'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'windows_device_id': windowsDeviceId,
      'android_device_id': androidDeviceId,
      'status': _connectionStatusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'initiated_by': initiatedBy,
      'other_device': otherDevice?.toJson(),
    };
  }

  static ConnectionStatus _connectionStatusFromString(String status) {
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
        return ConnectionStatus.pending;
    }
  }

  static String _connectionStatusToString(ConnectionStatus status) {
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

  DeviceConnection copyWith({
    String? id,
    String? windowsDeviceId,
    String? androidDeviceId,
    ConnectionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? initiatedBy,
    SignikDevice? otherDevice,
  }) {
    return DeviceConnection(
      id: id ?? this.id,
      windowsDeviceId: windowsDeviceId ?? this.windowsDeviceId,
      androidDeviceId: androidDeviceId ?? this.androidDeviceId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      otherDevice: otherDevice ?? this.otherDevice,
    );
  }
} 