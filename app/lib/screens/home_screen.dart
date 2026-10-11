import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';
import '../services/intercom_service.dart';
import 'convoy_room_screen.dart';
import 'qr_scanner_screen.dart';
import '../widgets/global_usage_modal.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _riderNameController = TextEditingController(text: 'Rider 1');
  final _roomNameController = TextEditingController(text: 'Sunday Morning Ride');
  final _pinController = TextEditingController();
  String _riderId = const Uuid().v4();
  bool _isLoading = false;

  @override
  void dispose() {
    _riderNameController.dispose();
    _roomNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  ConvoySession? _activeSession;

  @override
  void initState() {
    super.initState();
    _initRiderIdAndSavedRide();
  }

  Future<void> _initRiderIdAndSavedRide() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Persistent Rider Device ID across restarts/resumes
    var savedRiderId = prefs.getString('persistent_rider_id');
    if (savedRiderId == null || savedRiderId.isEmpty) {
      savedRiderId = const Uuid().v4();
      await prefs.setString('persistent_rider_id', savedRiderId);
    }
    _riderId = savedRiderId;

    // Load active ride
    final savedPin = prefs.getString('active_convoy_pin');
    final savedName = prefs.getString('active_convoy_name');
    final isHost = prefs.getBool('active_convoy_is_host') ?? false;

    if (savedPin != null && savedName != null) {
      setState(() {
        _activeSession = ConvoySession(
          token: '',
          roomName: savedName,
          roomPin: savedPin,
          liveKitUrl: '',
          isCreator: isHost,
        );
      });
    }

    // Auto check for update from NexEdar
    _checkForUpdates();
  }

  Future<void> _checkForUpdates({bool showNoUpdateNotice = false}) async {
    try {
      final release = await UpdateService.checkForUpdate();
      if (release != null && mounted) {
        await UpdateService.showUpdateDialog(context, release);
      } else if (showNoUpdateNotice && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NexRonda is up to date!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveActiveRide(ConvoySession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_convoy_pin', session.roomPin);
    await prefs.setString('active_convoy_name', session.roomName);
    await prefs.setBool('active_convoy_is_host', session.isCreator);
    setState(() => _activeSession = session);
  }

  Future<void> _clearActiveRide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_convoy_pin');
    await prefs.remove('active_convoy_name');
    await prefs.remove('active_convoy_is_host');
    setState(() => _activeSession = null);
  }

  Future<void> _createConvoy() async {
    if (_riderNameController.text.trim().isEmpty || _roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Rider Name and Convoy Name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final session = await ApiService.createRoom(
        name: _roomNameController.text.trim(),
        creatorId: _riderId,
        riderName: _riderNameController.text.trim(),
      );

      await _saveActiveRide(session);

      if (!mounted) return;
      final intercom = context.read<IntercomService>();
      await intercom.connect(
        session: session,
        riderId: _riderId,
        riderName: _riderNameController.text.trim(),
      );

      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ConvoyRoomScreen()),
      );
      if (result == 'ended') {
        await _clearActiveRide();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating convoy: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinConvoy({String? pinToUse}) async {
    final pin = pinToUse ?? _pinController.text.trim();
    if (_riderNameController.text.trim().isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and a valid 6-digit PIN')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      var session = await ApiService.joinRoom(
        pin: pin,
        riderId: _riderId,
        riderName: _riderNameController.text.trim(),
      );

      // If resuming a ride previously saved as host, guarantee isCreator is true
      if (!session.isCreator && _activeSession != null && _activeSession!.roomPin == pin && _activeSession!.isCreator) {
        session = ConvoySession(
          token: session.token,
          roomName: session.roomName,
          roomPin: session.roomPin,
          liveKitUrl: session.liveKitUrl,
          isCreator: true,
        );
      }

      await _saveActiveRide(session);

      if (!mounted) return;
      final intercom = context.read<IntercomService>();
      await intercom.connect(
        session: session,
        riderId: _riderId,
        riderName: _riderNameController.text.trim(),
      );

      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const ConvoyRoomScreen()),
      );
      if (result == 'ended') {
        await _clearActiveRide();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining convoy: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scanQr() async {
    final scannedPin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (scannedPin != null && scannedPin.isNotEmpty) {
      _pinController.text = scannedPin;
      _joinConvoy(pinToUse: scannedPin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // App Logo / Icon Header
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A8CC).withValues(alpha: 0.3),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'NexRonda',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Mesh Intercom & Convoy Telemetry',
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => GlobalUsageModal.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00A8CC).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, size: 13, color: Colors.greenAccent),
                          SizedBox(width: 5),
                          Text(
                            'SFU Limits',
                            style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _checkForUpdates(showNoUpdateNotice: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.system_update, size: 13, color: Colors.amberAccent),
                          SizedBox(width: 5),
                          Text(
                            'Check Update',
                            style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Active / Resume Convoy Card
              if (_activeSession != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00A8CC), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00A8CC).withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.two_wheeler, color: Color(0xFF00A8CC)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _activeSession!.roomName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A8CC).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PIN: ${_activeSession!.roomPin}',
                              style: const TextStyle(
                                color: Color(0xFF00A8CC),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('RESUME RIDE', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _isLoading ? null : () => _joinConvoy(pinToUse: _activeSession!.roomPin),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.outlined(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            tooltip: 'Dismiss',
                            onPressed: () => _clearActiveRide(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Rider Name field
              TextField(
                controller: _riderNameController,
                decoration: InputDecoration(
                  labelText: 'Rider Call-Sign / Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Create Convoy Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Host a New Convoy',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roomNameController,
                      decoration: InputDecoration(
                        labelText: 'Convoy Ride Title',
                        prefixIcon: const Icon(Icons.route),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isLoading ? null : _createConvoy,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('CREATE CONVOY ROOM', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Join Convoy with PIN
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Join Convoy with PIN',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: '6-Digit Convoy PIN',
                        prefixIcon: const Icon(Icons.pin),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _isLoading ? null : () => _joinConvoy(),
                            child: const Text('JOIN PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A8CC),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                            label: const Text('SCAN QR', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _isLoading ? null : _scanQr,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
