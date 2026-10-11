import 'dart:convert';
import 'package:http/http.dart' as http;

class ConvoySession {
  final String token;
  final String roomName;
  final String roomPin;
  final String liveKitUrl;
  final bool isCreator;

  ConvoySession({
    required this.token,
    required this.roomName,
    required this.roomPin,
    required this.liveKitUrl,
    this.isCreator = false,
  });

  factory ConvoySession.fromJson(Map<String, dynamic> json, {bool isCreator = false}) {
    return ConvoySession(
      token: json['token'] as String,
      roomName: json['room_name'] as String,
      roomPin: json['room_pin'] as String,
      liveKitUrl: json['livekit_url'] as String,
      isCreator: isCreator,
    );
  }
}

class ApiService {
  // Production signaling server domain
  static String baseUrl = 'https://ronda.nexkod.com';

  static Future<ConvoySession> createRoom({
    required String name,
    required String creatorId,
    required String riderName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rooms/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'creator_id': creatorId,
        'rider_name': riderName,
      }),
    );

    if (response.statusCode == 200) {
      return ConvoySession.fromJson(jsonDecode(response.body), isCreator: true);
    } else {
      throw Exception('Failed to create convoy room: ${response.body}');
    }
  }

  static Future<ConvoySession> joinRoom({
    required String pin,
    required String riderId,
    required String riderName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rooms/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pin': pin,
        'rider_id': riderId,
        'rider_name': riderName,
      }),
    );

    if (response.statusCode == 200) {
      return ConvoySession.fromJson(jsonDecode(response.body), isCreator: false);
    } else {
      throw Exception('Failed to join convoy room: ${response.body}');
    }
  }

  static Future<void> endRoom({
    required String pin,
    required String creatorId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rooms/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pin': pin,
        'creator_id': creatorId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to end convoy room: ${response.body}');
    }
  }

  static Future<GlobalUsageStats> getUsage() async {
    final response = await http.get(Uri.parse('$baseUrl/api/usage'));
    if (response.statusCode == 200) {
      return GlobalUsageStats.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch usage stats: ${response.body}');
    }
  }
}

class GlobalUsageStats {
  final String liveKitUrl;
  final int activeRooms;
  final int activeParticipants;
  final int maxParticipants;
  final double participantUsagePct;
  final double maxBandwidthGb;
  final String plan;
  final String status;
  final int registeredRooms;

  GlobalUsageStats({
    required this.liveKitUrl,
    required this.activeRooms,
    required this.activeParticipants,
    required this.maxParticipants,
    required this.participantUsagePct,
    required this.maxBandwidthGb,
    required this.plan,
    required this.status,
    required this.registeredRooms,
  });

  factory GlobalUsageStats.fromJson(Map<String, dynamic> json) {
    final lk = json['livekit'] as Map<String, dynamic>? ?? {};
    final convoys = json['convoys'] as Map<String, dynamic>? ?? {};

    return GlobalUsageStats(
      liveKitUrl: lk['url'] as String? ?? '',
      activeRooms: (lk['active_rooms'] as num?)?.toInt() ?? 0,
      activeParticipants: (lk['active_participants'] as num?)?.toInt() ?? 0,
      maxParticipants: (lk['max_participants'] as num?)?.toInt() ?? 100,
      participantUsagePct: (lk['participant_usage_pct'] as num?)?.toDouble() ?? 0.0,
      maxBandwidthGb: (lk['max_bandwidth_gb'] as num?)?.toDouble() ?? 50.0,
      plan: lk['plan'] as String? ?? 'LiveKit Cloud',
      status: lk['status'] as String? ?? 'healthy',
      registeredRooms: (convoys['registered_rooms'] as num?)?.toInt() ?? 0,
    );
  }
}
