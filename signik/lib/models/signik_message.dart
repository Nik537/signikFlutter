import 'dart:typed_data';

enum SignikMessageType {
  sendStart,
  signedComplete,
  signaturePreview,
  signatureAccepted,
  signatureDeclined,
  deferSignature,
  retrieveDeferred,
  heartbeat,
  deviceRegistration,
  unknown,
}

class SignikMessage {
  final SignikMessageType type;
  final String? name;
  final dynamic data;
  final String? docId;
  final String? deviceId;
  final int schemaVersion;

  SignikMessage({
    required this.type,
    this.name,
    this.data,
    this.docId,
    this.deviceId,
    this.schemaVersion = 1,
  });

  factory SignikMessage.fromJson(Map<String, dynamic> json) {
    return SignikMessage(
      type: _typeFromString(json['type'] as String?),
      name: json['name'] as String?,
      data: json['data'],
      docId: json['doc_id'] as String?,
      deviceId: json['device_id'] as String?,
      schemaVersion: json['schema_version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _typeToString(type),
      if (name != null) 'name': name,
      if (data != null) 'data': data,
      if (docId != null) 'doc_id': docId,
      if (deviceId != null) 'device_id': deviceId,
      'schema_version': schemaVersion,
    };
  }

  static SignikMessageType _typeFromString(String? type) {
    switch (type) {
      case 'sendStart':
        return SignikMessageType.sendStart;
      case 'signedComplete':
        return SignikMessageType.signedComplete;
      case 'signaturePreview':
        return SignikMessageType.signaturePreview;
      case 'signatureAccepted':
        return SignikMessageType.signatureAccepted;
      case 'signatureDeclined':
        return SignikMessageType.signatureDeclined;
      case 'deferSignature':
        return SignikMessageType.deferSignature;
      case 'retrieveDeferred':
        return SignikMessageType.retrieveDeferred;
      case 'heartbeat':
        return SignikMessageType.heartbeat;
      case 'deviceRegistration':
        return SignikMessageType.deviceRegistration;
      default:
        return SignikMessageType.unknown;
    }
  }

  static String _typeToString(SignikMessageType type) {
    switch (type) {
      case SignikMessageType.sendStart:
        return 'sendStart';
      case SignikMessageType.signedComplete:
        return 'signedComplete';
      case SignikMessageType.signaturePreview:
        return 'signaturePreview';
      case SignikMessageType.signatureAccepted:
        return 'signatureAccepted';
      case SignikMessageType.signatureDeclined:
        return 'signatureDeclined';
      case SignikMessageType.deferSignature:
        return 'deferSignature';
      case SignikMessageType.retrieveDeferred:
        return 'retrieveDeferred';
      case SignikMessageType.heartbeat:
        return 'heartbeat';
      case SignikMessageType.deviceRegistration:
        return 'deviceRegistration';
      default:
        return 'unknown';
    }
  }

  SignikMessage copyWith({
    SignikMessageType? type,
    String? name,
    dynamic data,
    String? docId,
    String? deviceId,
    int? schemaVersion,
  }) {
    return SignikMessage(
      type: type ?? this.type,
      name: name ?? this.name,
      data: data ?? this.data,
      docId: docId ?? this.docId,
      deviceId: deviceId ?? this.deviceId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
} 