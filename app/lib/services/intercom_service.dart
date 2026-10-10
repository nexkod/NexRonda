import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'api_service.dart';

enum IntercomState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum MicMode {
  vad, // Voice Activity Detection (Always open with gate)
  ptt, // Push-to-talk
}

class IntercomService extends ChangeNotifier {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  IntercomState _state = IntercomState.disconnected;
  IntercomState get state => _state;

  MicMode _micMode = MicMode.vad;
  MicMode get micMode => _micMode;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isPttPressed = false;
  bool get isPttPressed => _isPttPressed;

  ConvoySession? _session;
  ConvoySession? get session => _session;

  List<Participant> _participants = [];
  List<Participant> get participants => _participants;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void setMicMode(MicMode mode) {
    _micMode = mode;
    if (_micMode == MicMode.ptt) {
      _setMicEnabled(false);
    } else {
      _setMicEnabled(!_isMuted);
    }
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _setMicEnabled(!_isMuted);
    notifyListeners();
  }

  void pttDown() {
    if (_micMode == MicMode.ptt) {
      _isPttPressed = true;
      _setMicEnabled(true);
      notifyListeners();
    }
  }

  void pttUp() {
    if (_micMode == MicMode.ptt) {
      _isPttPressed = false;
      _setMicEnabled(false);
      notifyListeners();
    }
  }

  Future<void> connect(ConvoySession session) async {
    _session = session;
    _state = IntercomState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'rider-audio',
            dtx: true, // Discontinuous transmission to save mobile data
          ),
        ),
      );

      _listener = _room!.createListener();
      _setupListeners();

      // Connect to LiveKit Room
      await _room!.connect(
        session.liveKitUrl,
        session.token,
      );

      // Publish local audio track with noise suppression
      await _room!.localParticipant?.setMicrophoneEnabled(
        _micMode == MicMode.vad ? true : false,
      );

      _state = IntercomState.connected;
      _updateParticipants();
      notifyListeners();
    } catch (e) {
      _state = IntercomState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _setupListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        _state = IntercomState.disconnected;
        notifyListeners();
      })
      ..on<RoomReconnectingEvent>((event) {
        _state = IntercomState.reconnecting;
        notifyListeners();
      })
      ..on<RoomReconnectedEvent>((event) {
        _state = IntercomState.connected;
        notifyListeners();
      })
      ..on<ParticipantConnectedEvent>((event) {
        _updateParticipants();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _updateParticipants();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        notifyListeners();
      });
  }

  void _updateParticipants() {
    if (_room == null) {
      _participants = [];
    } else {
      _participants = [
        if (_room!.localParticipant != null) _room!.localParticipant!,
        ..._room!.remoteParticipants.values,
      ];
    }
    notifyListeners();
  }

  Future<void> _setMicEnabled(bool enabled) async {
    if (_room?.localParticipant != null) {
      await _room!.localParticipant!.setMicrophoneEnabled(enabled);
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _session = null;
    _state = IntercomState.disconnected;
    _participants = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }
}
