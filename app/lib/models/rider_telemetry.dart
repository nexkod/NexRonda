import 'dart:convert';

class TargetDestination {
  final String title;
  final double latitude;
  final double longitude;
  final String setBy;

  TargetDestination({
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.setBy,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'lat': latitude,
        'lng': longitude,
        'setBy': setBy,
      };

  factory TargetDestination.fromJson(Map<String, dynamic> json) => TargetDestination(
        title: json['title'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
        setBy: json['setBy'] as String? ?? 'Host',
      );
}

class RiderTelemetry {
  final String riderId;
  final String riderName;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final int batteryLevel;
  final bool isSos;
  final int timestamp;
  final TargetDestination? destination;

  // Whisper / 1-on-1 private talk target (if empty, talk to whole convoy)
  final String? privateTargetRiderId;

  RiderTelemetry({
    required this.riderId,
    required this.riderName,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.batteryLevel,
    this.isSos = false,
    required this.timestamp,
    this.destination,
    this.privateTargetRiderId,
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
        if (destination != null) 'dest': destination!.toJson(),
        if (privateTargetRiderId != null) 'whisper': privateTargetRiderId,
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
        destination: json['dest'] != null ? TargetDestination.fromJson(json['dest']) : null,
        privateTargetRiderId: json['whisper'] as String?,
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
