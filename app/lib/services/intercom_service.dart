import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/rider_telemetry.dart';
import 'api_service.dart';

enum IntercomState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum MicMode {
  vad, // Voice Activity Detection
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

  String _localRiderId = '';
  String _localRiderName = '';
  String get localRiderId => _localRiderId;
  String get localRiderName => _localRiderName;

  List<Participant> _participants = [];
  List<Participant> get participants => _participants;

  // Real-time Convoy Telemetry Map: riderId -> RiderTelemetry
  final Map<String, RiderTelemetry> _telemetries = {};
  Map<String, RiderTelemetry> get telemetries => _telemetries;

  bool _isSosActive = false;
  bool get isSosActive => _isSosActive;

  String? _sosRiderName;
  String? get sosRiderName => _sosRiderName;

  Timer? _telemetryTimer;
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  final Battery _battery = Battery();
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

  // Trigger Emergency SOS broadcast
  Future<void> toggleSos() async {
    _isSosActive = !_isSosActive;
    if (_isSosActive) {
      _sosRiderName = _localRiderName;
    } else {
      _sosRiderName = null;
    }
    notifyListeners();
    await _broadcastTelemetry();
  }

  Future<void> connect({
    required ConvoySession session,
    required String riderId,
    required String riderName,
  }) async {
    _session = session;
    _localRiderId = riderId;
    _localRiderName = riderName;
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
            dtx: true,
          ),
        ),
      );

      _listener = _room!.createListener();
      _setupListeners();

      await _room!.connect(
        session.liveKitUrl,
        session.token,
      );

      await _room!.localParticipant?.setMicrophoneEnabled(
        _micMode == MicMode.vad ? true : false,
      );

      _state = IntercomState.connected;
      _updateParticipants();
      _startTelemetryBroadcasting();
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
        _stopTelemetryBroadcasting();
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
        _telemetries.remove(event.participant.identity);
        _updateParticipants();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        notifyListeners();
      })
      ..on<DataReceivedEvent>((event) {
        _handleDataReceived(event);
      });
  }

  void _handleDataReceived(DataReceivedEvent event) {
    try {
      final raw = utf8.decode(event.data);
      final telemetry = RiderTelemetry.deserialize(raw);
      if (telemetry != null) {
        _telemetries[telemetry.riderId] = telemetry;
        if (telemetry.isSos) {
          _sosRiderName = telemetry.riderName;
        } else if (_sosRiderName == telemetry.riderName) {
          _sosRiderName = null;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _startTelemetryBroadcasting() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          _currentPosition = pos;
          _broadcastTelemetry();
        });
      }
    } catch (_) {}

    // Periodic keep-alive broadcast every 3 seconds
    _telemetryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _broadcastTelemetry();
    });
  }

  Future<void> _broadcastTelemetry() async {
    if (_room == null || _state != IntercomState.connected) return;

    int battery = 100;
    try {
      battery = await _battery.batteryLevel;
    } catch (_) {}

    final telemetry = RiderTelemetry(
      riderId: _localRiderId,
      riderName: _localRiderName,
      latitude: _currentPosition?.latitude ?? 3.1390,
      longitude: _currentPosition?.longitude ?? 101.6869,
      speedKmh: (_currentPosition?.speed ?? 0.0) * 3.6,
      batteryLevel: battery,
      isSos: _isSosActive,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _telemetries[_localRiderId] = telemetry;

    final bytes = utf8.encode(telemetry.serialize());
    try {
      await _room!.localParticipant?.publishData(bytes);
    } catch (_) {}
    notifyListeners();
  }

  void _stopTelemetryBroadcasting() {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
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
    _stopTelemetryBroadcasting();
    await _room?.disconnect();
    await _room?.dispose();
    _room = null;
    _session = null;
    _state = IntercomState.disconnected;
    _participants = [];
    _telemetries.clear();
    _isSosActive = false;
    _sosRiderName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTelemetryBroadcasting();
    _listener?.dispose();
    _room?.dispose();
    super.dispose();
  }
}
