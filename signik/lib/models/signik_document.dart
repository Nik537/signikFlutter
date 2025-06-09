enum SignikDocumentStatus {
  queued,
  sent,
  signed,
  declined,
  deferred,
  delivered,
  error,
}

class SignikDocument {
  final String id;
  final String name;
  final String? path;
  final SignikDocumentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? windowsDeviceId;
  final String? androidDeviceId;

  SignikDocument({
    required this.id,
    required this.name,
    this.path,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.windowsDeviceId,
    this.androidDeviceId,
  });

  factory SignikDocument.fromJson(Map<String, dynamic> json) {
    return SignikDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String?,
      status: _statusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      windowsDeviceId: json['windows_device_id'] as String?,
      androidDeviceId: json['android_device_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (path != null) 'path': path,
      'status': _statusToString(status),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (windowsDeviceId != null) 'windows_device_id': windowsDeviceId,
      if (androidDeviceId != null) 'android_device_id': androidDeviceId,
    };
  }

  static SignikDocumentStatus _statusFromString(String status) {
    switch (status) {
      case 'queued':
        return SignikDocumentStatus.queued;
      case 'sent':
        return SignikDocumentStatus.sent;
      case 'signed':
        return SignikDocumentStatus.signed;
      case 'declined':
        return SignikDocumentStatus.declined;
      case 'deferred':
        return SignikDocumentStatus.deferred;
      case 'delivered':
        return SignikDocumentStatus.delivered;
      default:
        return SignikDocumentStatus.error;
    }
  }

  static String _statusToString(SignikDocumentStatus status) {
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

  SignikDocument copyWith({
    String? id,
    String? name,
    String? path,
    SignikDocumentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? windowsDeviceId,
    String? androidDeviceId,
  }) {
    return SignikDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      windowsDeviceId: windowsDeviceId ?? this.windowsDeviceId,
      androidDeviceId: androidDeviceId ?? this.androidDeviceId,
    );
  }
} 