import 'dart:typed_data';

enum SignikMessageType {
  sendStart,
  signedComplete,
  unknown,
}

class SignikMessage {
  final SignikMessageType type;
  final String? name;
  final dynamic data;

  SignikMessage({required this.type, this.name, this.data});

  factory SignikMessage.fromJson(Map<String, dynamic> json) {
    return SignikMessage(
      type: _typeFromString(json['type'] as String?),
      name: json['name'] as String?,
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': _typeToString(type),
      if (name != null) 'name': name,
      if (data != null) 'data': data,
    };
  }

  static SignikMessageType _typeFromString(String? type) {
    switch (type) {
      case 'sendStart':
        return SignikMessageType.sendStart;
      case 'signedComplete':
        return SignikMessageType.signedComplete;
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
      default:
        return 'unknown';
    }
  }
} 