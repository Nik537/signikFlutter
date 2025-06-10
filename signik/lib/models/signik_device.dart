/// Represents the type of device in the Signik system
enum DeviceType {
  windows,
  android,
}

class SignikDevice {
  final String id;
  final String name;
  final DeviceType deviceType;
  final String? ipAddress;
  final DateTime lastHeartbeat;
  final bool isOnline;

  SignikDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    this.ipAddress,
    required this.lastHeartbeat,
    this.isOnline = true,
  });
  
  /// Convenience getter for device type as string
  String get type => deviceType.name;

  factory SignikDevice.fromJson(Map<String, dynamic> json) {
    return SignikDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceType: DeviceType.values.byName(json['device_type'] as String? ?? 'android'),
      ipAddress: json['ip_address'] as String?,
      lastHeartbeat: DateTime.parse(json['last_heartbeat'] as String),
      isOnline: json['is_online'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'device_type': deviceType.name,
      'ip_address': ipAddress,
      'last_heartbeat': lastHeartbeat.toIso8601String(),
      'is_online': isOnline,
    };
  }


  SignikDevice copyWith({
    String? id,
    String? name,
    DeviceType? deviceType,
    String? ipAddress,
    DateTime? lastHeartbeat,
    bool? isOnline,
  }) {
    return SignikDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      ipAddress: ipAddress ?? this.ipAddress,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      isOnline: isOnline ?? this.isOnline,
    );
  }
} 