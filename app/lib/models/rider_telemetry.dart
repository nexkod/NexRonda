import 'dart:convert';

class RiderTelemetry {
  final String riderId;
  final String riderName;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final int batteryLevel;
  final bool isSos;
  final int timestamp;

  RiderTelemetry({
    required this.riderId,
    required this.riderName,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.batteryLevel,
    this.isSos = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'riderId': riderId,
        'riderName': riderName,
        'lat': latitude,
        'lng': longitude,
        'speed': speedKmh,
        'battery': batteryLevel,
        'sos': isSos,
        'ts': timestamp,
      };

  factory RiderTelemetry.fromJson(Map<String, dynamic> json) => RiderTelemetry(
        riderId: json['riderId'] as String,
        riderName: json['riderName'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        speedKmh: (json['speed'] as num?)?.toDouble() ?? 0.0,
        batteryLevel: (json['battery'] as num?)?.toInt() ?? 100,
        isSos: json['sos'] as bool? ?? false,
        timestamp: (json['ts'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      );

  String serialize() => jsonEncode(toJson());

  static RiderTelemetry? deserialize(String raw) {
    try {
      return RiderTelemetry.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
