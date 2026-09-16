enum DeviceKind { hub, cam, loadCell, ultrasonic }

enum DeviceStatus { online, offline, lowBattery }

class Device {
  final String id;
  final String name;
  final DeviceKind kind;
  final DeviceStatus status;
  final int? batteryPct;
  final String meta;
  final String? ipAddress;

  const Device({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    this.batteryPct,
    this.meta = '',
    this.ipAddress,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: DeviceKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => DeviceKind.hub,
      ),
      status: DeviceStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      batteryPct: (json['battery_pct'] as num?)?.toInt(),
      meta: json['meta'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
    );
  }
}
