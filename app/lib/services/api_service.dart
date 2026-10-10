import 'dart:convert';
import 'package:http/http.dart' as http;

class ConvoySession {
  final String token;
  final String roomName;
  final String roomPin;
  final String liveKitUrl;

  ConvoySession({
    required this.token,
    required this.roomName,
    required this.roomPin,
    required this.liveKitUrl,
  });

  factory ConvoySession.fromJson(Map<String, dynamic> json) {
    return ConvoySession(
      token: json['token'] as String,
      roomName: json['room_name'] as String,
      roomPin: json['room_pin'] as String,
      liveKitUrl: json['livekit_url'] as String,
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
      return ConvoySession.fromJson(jsonDecode(response.body));
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
      return ConvoySession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to join convoy room: ${response.body}');
    }
  }
}
