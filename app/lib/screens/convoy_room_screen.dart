import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../services/intercom_service.dart';

class ConvoyRoomScreen extends StatelessWidget {
  const ConvoyRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final intercom = context.watch<IntercomService>();
    final session = intercom.session;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session?.roomName ?? 'Convoy Ride',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                  intercom.state.name.toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 12),
                Text(
                  'PIN: ${session?.roomPin ?? ""}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.redAccent),
            tooltip: 'Leave Convoy',
            onPressed: () async {
              await intercom.disconnect();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode selector (VAD vs PTT)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

            // Rider participants grid
            Expanded(
              child: intercom.participants.isEmpty
                  ? const Center(
                      child: Text(
                        'Waiting for convoy riders to join...',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: intercom.participants.length,
                      itemBuilder: (context, index) {
                        final participant = intercom.participants[index];
                        final isSpeaking = participant.isSpeaking;

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
                                    ? Colors.greenAccent.withOpacity(0.2)
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
                                      participant.name.isNotEmpty
                                          ? participant.name
                                          : participant.identity,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      participant is LocalParticipant
                                          ? 'You (Lead/Rider)'
                                          : 'Rider in Mesh',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSpeaking)
                                const Icon(
                                  Icons.volume_up,
                                  color: Colors.greenAccent,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Audio Controls / PTT trigger
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: intercom.micMode == MicMode.ptt
                  ? GestureDetector(
                      onTapDown: (_) => intercom.pttDown(),
                      onTapUp: (_) => intercom.pttUp(),
                      onTapCancel: () => intercom.pttUp(),
                      child: Container(
                        width: double.infinity,
                        height: 70,
                        decoration: BoxDecoration(
                          color: intercom.isPttPressed
                              ? Colors.redAccent
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                intercom.isPttPressed ? Icons.mic : Icons.mic_none,
                                size: 28,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                intercom.isPttPressed
                                    ? 'TRANSMITTING VOICE...'
                                    : 'HOLD TO TALK (PTT)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton.filledTonal(
                          iconSize: 32,
                          icon: Icon(
                            intercom.isMuted ? Icons.mic_off : Icons.mic,
                            color: intercom.isMuted ? Colors.redAccent : Colors.white,
                          ),
                          onPressed: () => intercom.toggleMute(),
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
