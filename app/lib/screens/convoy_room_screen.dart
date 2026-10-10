import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/intercom_service.dart';

class ConvoyRoomScreen extends StatefulWidget {
  const ConvoyRoomScreen({super.key});

  @override
  State<ConvoyRoomScreen> createState() => _ConvoyRoomScreenState();
}

class _ConvoyRoomScreenState extends State<ConvoyRoomScreen> {
  final MapController _mapController = MapController();
  bool _showRadarMap = true;

  void _showQrDialog(BuildContext context, String pin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Convoy QR Pass', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: pin,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PIN: $pin',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Color(0xFF00A8CC),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask nearby riders to scan this code to join convoy mesh voice instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final intercom = context.watch<IntercomService>();
    final session = intercom.session;
    final pin = session?.roomPin ?? '';

    // Calculate map center from local rider position
    final localPos = intercom.currentPosition;
    final centerLatLng = localPos != null
        ? LatLng(localPos.latitude, localPos.longitude)
        : const LatLng(3.1390, 101.6869);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session?.roomName ?? 'Convoy Ride',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: intercom.state == IntercomState.connected
                        ? Colors.greenAccent
                        : intercom.state == IntercomState.reconnecting
                            ? Colors.amberAccent
                            : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  intercom.state == IntercomState.reconnecting
                      ? 'TUNNEL / RECONNECTING...'
                      : intercom.state.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: intercom.state == IntercomState.reconnecting
                        ? Colors.amberAccent
                        : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'PIN: $pin',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00A8CC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Show Convoy QR',
            onPressed: () => _showQrDialog(context, pin),
          ),
          IconButton(
            icon: Icon(_showRadarMap ? Icons.view_list : Icons.map),
            tooltip: _showRadarMap ? 'View Riders List' : 'View GPS Radar Map',
            onPressed: () => setState(() => _showRadarMap = !_showRadarMap),
          ),
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.redAccent),
            tooltip: 'Leave Convoy',
            onPressed: () async {
              await intercom.disconnect();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // SOS Alert Banner if anyone triggered emergency
            if (intercom.sosRiderName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: Colors.redAccent.shade700,
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'EMERGENCY SOS: ${intercom.sosRiderName} needs immediate assistance!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Mode Selector (Open Mic VAD vs PTT)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: SegmentedButton<MicMode>(
                segments: const [
                  ButtonSegment(
                    value: MicMode.vad,
                    label: Text('Open Mic (VAD)'),
                    icon: Icon(Icons.record_voice_over),
                  ),
                  ButtonSegment(
                    value: MicMode.ptt,
                    label: Text('Push-to-Talk'),
                    icon: Icon(Icons.touch_app),
                  ),
                ],
                selected: {intercom.micMode},
                onSelectionChanged: (newSelection) {
                  intercom.setMicMode(newSelection.first);
                },
              ),
            ),

            // Main Content: Convoy Radar Map OR Riders List
            Expanded(
              child: _showRadarMap
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: centerLatLng,
                              initialZoom: 15.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.nexkod.nexronda',
                              ),
                              MarkerLayer(
                                markers: intercom.telemetries.values.map((t) {
                                  final isSelf = t.riderId == intercom.localRiderId;
                                  return Marker(
                                    point: LatLng(t.latitude, t.longitude),
                                    width: 80,
                                    height: 80,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: t.isSos ? Colors.redAccent : const Color(0xFF00A8CC),
                                            ),
                                          ),
                                          child: Text(
                                            '${t.riderName} (${t.speedKmh.toInt()} km/h)',
                                            style: TextStyle(
                                              color: t.isSos ? Colors.redAccent : Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Icon(
                                          Icons.two_wheeler,
                                          size: 32,
                                          color: t.isSos
                                              ? Colors.redAccent
                                              : isSelf
                                                  ? Colors.greenAccent
                                                  : const Color(0xFF00A8CC),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              backgroundColor: const Color(0xFF1E293B),
                              onPressed: () {
                                _mapController.move(centerLatLng, 15.0);
                              },
                              child: const Icon(Icons.my_location, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: intercom.participants.length,
                      itemBuilder: (context, index) {
                        final participant = intercom.participants[index];
                        final isSpeaking = participant.isSpeaking;
                        final t = intercom.telemetries[participant.identity];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSpeaking ? Colors.greenAccent : Colors.white12,
                              width: isSpeaking ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isSpeaking
                                    ? Colors.greenAccent.withValues(alpha: 0.2)
                                    : Colors.white10,
                                child: Icon(
                                  Icons.two_wheeler,
                                  color: isSpeaking ? Colors.greenAccent : Colors.white70,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      participant.name.isNotEmpty ? participant.name : participant.identity,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Speed: ${t?.speedKmh.toInt() ?? 0} km/h • ',
                                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                                        ),
                                        Icon(
                                          Icons.battery_std,
                                          size: 14,
                                          color: (t?.batteryLevel ?? 100) > 20
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                        ),
                                        Text(
                                          '${t?.batteryLevel ?? 100}%',
                                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSpeaking)
                                const Icon(Icons.volume_up, color: Colors.greenAccent),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Audio Controls / PTT trigger & Emergency SOS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // Emergency SOS button
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: intercom.isSosActive ? Colors.redAccent : Colors.red.shade900,
                    ),
                    icon: const Icon(Icons.sos, color: Colors.white),
                    tooltip: 'Emergency SOS Broadcast',
                    onPressed: () => intercom.toggleSos(),
                  ),
                  const SizedBox(width: 12),

                  // Mic Controls or PTT
                  Expanded(
                    child: intercom.micMode == MicMode.ptt
                        ? GestureDetector(
                            onTapDown: (_) => intercom.pttDown(),
                            onTapUp: (_) => intercom.pttUp(),
                            onTapCancel: () => intercom.pttUp(),
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: intercom.isPttPressed ? Colors.redAccent : const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      intercom.isPttPressed ? Icons.mic : Icons.mic_none,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      intercom.isPttPressed ? 'TRANSMITTING...' : 'HOLD TO TALK (PTT)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: intercom.isMuted ? Colors.redAccent : const Color(0xFF10B981),
                              ),
                            ),
                            icon: Icon(
                              intercom.isMuted ? Icons.mic_off : Icons.mic,
                              color: intercom.isMuted ? Colors.redAccent : const Color(0xFF10B981),
                            ),
                            label: Text(
                              intercom.isMuted ? 'UNMUTE MIC' : 'MUTE MIC',
                              style: TextStyle(
                                color: intercom.isMuted ? Colors.redAccent : const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => intercom.toggleMute(),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
