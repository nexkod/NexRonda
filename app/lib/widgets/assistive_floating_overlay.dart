import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Entry point executed inside the floating overlay Android window
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AssistiveFloatingOverlay(),
    ),
  );
}

class AssistiveFloatingOverlay extends StatefulWidget {
  const AssistiveFloatingOverlay({super.key});

  @override
  State<AssistiveFloatingOverlay> createState() => _AssistiveFloatingOverlayState();
}

class _AssistiveFloatingOverlayState extends State<AssistiveFloatingOverlay> {
  bool _isExpanded = false;
  bool _isMuted = false;
  bool _isPttActive = false;
  String _activeSpeaker = '';
  String _roomName = 'Convoy';
  bool _isSos = false;

  @override
  void initState() {
    super.initState();
    // Listen to telemetry / audio events from main Flutter app isolate
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event == null) return;
      try {
        final data = event is String ? jsonDecode(event) : event;
        if (data is Map) {
          setState(() {
            if (data.containsKey('isMuted')) _isMuted = data['isMuted'] as bool;
            if (data.containsKey('activeSpeaker')) _activeSpeaker = data['activeSpeaker'] as String? ?? '';
            if (data.containsKey('roomName')) _roomName = data['roomName'] as String? ?? 'Convoy';
            if (data.containsKey('isSos')) _isSos = data['isSos'] as bool? ?? false;
          });
        }
      } catch (_) {}
    });
  }

  void _sendAction(String action, [dynamic value]) {
    FlutterOverlayWindow.shareData(jsonEncode({
      'action': action,
      'value': value,
    }));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      // Compact Bubble Mode (Draggable Circle, pulsing when talking)
      return Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.center,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _isExpanded = true);
            },
            onLongPressStart: (_) {
              setState(() => _isPttActive = true);
              _sendAction('ptt_down');
            },
            onLongPressEnd: (_) {
              setState(() => _isPttActive = false);
              _sendAction('ptt_up');
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSos
                    ? Colors.redAccent.shade700
                    : _isPttActive
                        ? const Color(0xFF10B981)
                        : _activeSpeaker.isNotEmpty
                            ? Colors.green.shade600
                            : const Color(0xFF1E293B),
                border: Border.all(
                  color: _isSos
                      ? Colors.white
                      : _activeSpeaker.isNotEmpty || _isPttActive
                          ? Colors.greenAccent
                          : const Color(0xFF00A8CC),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isSos
                            ? Colors.redAccent
                            : _activeSpeaker.isNotEmpty || _isPttActive
                                ? Colors.greenAccent
                                : const Color(0xFF00A8CC))
                        .withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isSos
                      ? Icons.warning_amber
                      : _isPttActive
                          ? Icons.mic
                          : _isMuted
                              ? Icons.mic_off
                              : Icons.two_wheeler,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Expanded Mini Control Bar Mode
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Invisible dismissable backdrop: tap outside collapses back to bubble!
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _isExpanded = false);
              },
            ),
          ),
          Center(
            child: Container(
              width: 270,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00A8CC), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header title + collapse button
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _activeSpeaker.isNotEmpty ? Colors.greenAccent : const Color(0xFF00A8CC),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _activeSpeaker.isNotEmpty
                              ? 'Speaking: $_activeSpeaker'
                              : _roomName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _isExpanded = false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 8),

              // Action buttons row (Mute, Hold PTT, Return to App)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute Toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                      _sendAction('toggle_mute');
                    },
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: _isMuted ? Colors.redAccent.shade400 : const Color(0xFF0F172A),
                      child: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  // Hold-to-Talk PTT Button
                  GestureDetector(
                    onTapDown: (_) {
                      setState(() => _isPttActive = true);
                      _sendAction('ptt_down');
                    },
                    onTapUp: (_) {
                      setState(() => _isPttActive = false);
                      _sendAction('ptt_up');
                    },
                    onTapCancel: () {
                      setState(() => _isPttActive = false);
                      _sendAction('ptt_up');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isPttActive ? const Color(0xFF10B981) : const Color(0xFF00A8CC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isPttActive ? Icons.radio_button_checked : Icons.touch_app, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _isPttActive ? 'TALKING' : 'HOLD PTT',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Return to NexRonda app
                  GestureDetector(
                    onTap: () {
                      _sendAction('open_app');
                    },
                    child: const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFF0F172A),
                      child: Icon(
                        Icons.open_in_full,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }
}
