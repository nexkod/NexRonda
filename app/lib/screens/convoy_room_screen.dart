import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rider_telemetry.dart';
import '../services/api_service.dart';
import '../services/intercom_service.dart';
import '../utils/map_link_parser.dart';
import '../widgets/global_usage_modal.dart';

class ConvoyRoomScreen extends StatefulWidget {
  const ConvoyRoomScreen({super.key});

  @override
  State<ConvoyRoomScreen> createState() => _ConvoyRoomScreenState();
}

class _ConvoyRoomScreenState extends State<ConvoyRoomScreen> {
  final MapController _mapController = MapController();
  bool _showRadarMap = true;
  bool _hasFittedInitialBounds = false;

  void _fitAllRidersAndDestination(IntercomService intercom) {
    final points = <LatLng>[];

    // Local position
    if (intercom.currentPosition != null) {
      points.add(LatLng(intercom.currentPosition!.latitude, intercom.currentPosition!.longitude));
    }

    // Remote riders
    for (final t in intercom.telemetries.values) {
      if (t.latitude != 0.0 && t.longitude != 0.0) {
        points.add(LatLng(t.latitude, t.longitude));
      }
    }

    // Destination
    if (intercom.destination != null &&
        intercom.destination!.latitude != 0.0 &&
        intercom.destination!.longitude != 0.0) {
      points.add(LatLng(intercom.destination!.latitude, intercom.destination!.longitude));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (_) {}
  }

  void _focusOnRider(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return;
    setState(() {
      _showRadarMap = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(LatLng(lat, lng), 16.5);
    });
  }

  Future<void> _openNavigationApp(double lat, double lng, String label) async {
    // Universal geo scheme opening Apple Maps on iOS or Google Maps / Waze
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    final wazeUrl = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    if (await canLaunchUrl(appleMapsUrl)) {
      await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showSetDestinationDialog(BuildContext context) {
    final titleController = TextEditingController(text: 'Genting Highlands BHP Petrol');
    final latController = TextEditingController(text: '3.4237');
    final lngController = TextEditingController(text: '101.7932');
    final linkController = TextEditingController();
    bool isParsing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> handleParseLink(String text) async {
            if (text.trim().isEmpty) return;
            setDialogState(() => isParsing = true);
            final result = await MapLinkParser.parse(text);
            setDialogState(() => isParsing = false);

            if (result != null) {
              latController.text = result.latitude.toStringAsFixed(6);
              lngController.text = result.longitude.toStringAsFixed(6);
              if (result.label != null && result.label!.isNotEmpty) {
                titleController.text = result.label!;
              }
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Extracted coordinates: ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}'),
                    backgroundColor: const Color(0xFF00A8CC),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } else {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Could not extract coordinates from link. Please verify URL.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Set Convoy Destination'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paste Map Link Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00A8CC).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.link, size: 16, color: Color(0xFF00A8CC)),
                            const SizedBox(width: 6),
                            const Text(
                              'Paste Map Link / Coordinates',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A8CC),
                              ),
                            ),
                            const Spacer(),
                            // Quick Paste button from Clipboard
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.content_paste, size: 13, color: Colors.amberAccent),
                              label: const Text('PASTE', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null && data!.text!.isNotEmpty) {
                                  linkController.text = data.text!;
                                  await handleParseLink(data.text!);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: linkController,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Google Maps / Apple Maps / Waze link or 3.14,101.68',
                                  hintStyle: const TextStyle(fontSize: 11, color: Colors.white38),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: isParsing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00A8CC)),
                                    )
                                  : const Icon(Icons.arrow_forward, color: Color(0xFF00A8CC), size: 20),
                              tooltip: 'Parse Link',
                              onPressed: isParsing ? null : () => handleParseLink(linkController.text),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Destination Name / Waypoint'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lngController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A8CC)),
                onPressed: () {
                  final lat = double.tryParse(latController.text.trim()) ?? 0.0;
                  final lng = double.tryParse(lngController.text.trim()) ?? 0.0;
                  if (titleController.text.isNotEmpty && lat != 0.0) {
                    final intercom = context.read<IntercomService>();
                    intercom.setDestination(TargetDestination(
                      title: titleController.text.trim(),
                      latitude: lat,
                      longitude: lng,
                      setBy: intercom.localRiderName,
                    ));
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('BROADCAST DESTINATION', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQrDialog(BuildContext context, String pin) {
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Convoy PIN available to display')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Convoy QR Pass', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: QrImageView(
                  data: pin,
                  version: QrVersions.auto,
                  size: 190.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0F172A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'PIN: $pin',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Color(0xFF00A8CC),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Riders can scan this code from their app to join your convoy room immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session?.roomName ?? 'Convoy Ride',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: intercom.state == IntercomState.connected
                        ? Colors.greenAccent
                        : intercom.state == IntercomState.reconnecting
                            ? Colors.amberAccent
                            : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  intercom.state == IntercomState.reconnecting
                      ? 'RECONNECTING...'
                      : intercom.state.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: intercom.state == IntercomState.reconnecting
                        ? Colors.amberAccent
                        : Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'PIN: $pin',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF00A8CC),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle Map / List
          IconButton(
            icon: Icon(_showRadarMap ? Icons.view_list : Icons.map, size: 22),
            tooltip: _showRadarMap ? 'View Riders List' : 'View GPS Radar Map',
            onPressed: () => setState(() => _showRadarMap = !_showRadarMap),
          ),
          // More options menu (Clean & uncluttered)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'destination') {
                _showSetDestinationDialog(context);
              } else if (val == 'qr') {
                _showQrDialog(context, pin);
              } else if (val == 'usage') {
                GlobalUsageModal.show(context);
              } else if (val == 'fit_map') {
                _fitAllRidersAndDestination(intercom);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'destination',
                child: Row(
                  children: [
                    Icon(Icons.add_location_alt, color: Color(0xFF00A8CC), size: 18),
                    SizedBox(width: 10),
                    Text('Set Destination', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Convoy QR Pass', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'usage',
                child: Row(
                  children: [
                    Icon(Icons.cloud_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('SFU & Data Usage', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fit_map',
                child: Row(
                  children: [
                    Icon(Icons.zoom_out_map, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Fit All on Map', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          // Leave or End Convoy
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.redAccent, size: 22),
            tooltip: 'Leave or End Convoy',
            onPressed: () async {
              final isHost = session?.isCreator ?? false;
              final action = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: Text(isHost ? 'Convoy Options' : 'Leave Convoy?'),
                  content: Text(
                    isHost
                        ? 'Do you want to pause/leave the ride (PIN remains active so you can resume later), or permanently end the convoy for all riders?'
                        : 'Are you sure you want to disconnect from this convoy ride?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('cancel'),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop('leave'),
                      child: const Text('LEAVE (CAN RESUME)'),
                    ),
                    if (isHost)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.of(ctx).pop('end_all'),
                        child: const Text('END CONVOY FOR ALL', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              );

              if (action == 'leave') {
                await intercom.disconnect();
                if (context.mounted) Navigator.of(context).pop();
              } else if (action == 'end_all' && session != null) {
                try {
                  await ApiService.endRoom(
                    pin: session.roomPin,
                    creatorId: intercom.localRiderId,
                  );
                } catch (_) {}
                await intercom.disconnect();
                if (context.mounted) Navigator.of(context).pop('ended');
              }
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

            // Target Destination Waypoint Banner (Tap to open Navigation App)
            if (intercom.destination != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A8CC).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00A8CC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation, color: Color(0xFF00A8CC), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            intercom.destination!.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Target Waypoint • Shared by ${intercom.destination!.setBy}',
                            style: const TextStyle(fontSize: 10, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                      tooltip: 'Copy Destination Map Link',
                      onPressed: () {
                        final lat = intercom.destination!.latitude;
                        final lng = intercom.destination!.longitude;
                        final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                        Clipboard.setData(ClipboardData(text: mapUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Destination map link copied to clipboard!'),
                            backgroundColor: Color(0xFF00A8CC),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A8CC),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text('NAVIGATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _openNavigationApp(
                        intercom.destination!.latitude,
                        intercom.destination!.longitude,
                        intercom.destination!.title,
                      ),
                    ),
                  ],
                ),
              ),

            // Private 1-on-1 Whisper Mode Banner
            if (intercom.privateTalkTargetName != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade900.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purpleAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Colors.purpleAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '1-on-1 Whisper Mode with ${intercom.privateTalkTargetName}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      onPressed: () => intercom.setPrivateTalkTarget(null, null),
                      child: const Text('RESET TO ALL', style: TextStyle(color: Colors.purpleAccent, fontSize: 11)),
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
                              onMapReady: () {
                                if (!_hasFittedInitialBounds) {
                                  _hasFittedInitialBounds = true;
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _fitAllRidersAndDestination(intercom);
                                  });
                                }
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.nexkod.nexronda',
                              ),
                              MarkerLayer(
                                markers: [
                                  // Destination Waypoint Flag Marker
                                  if (intercom.destination != null)
                                    Marker(
                                      point: LatLng(
                                        intercom.destination!.latitude,
                                        intercom.destination!.longitude,
                                      ),
                                      width: 100,
                                      height: 90,
                                      child: GestureDetector(
                                        onTap: () => _openNavigationApp(
                                          intercom.destination!.latitude,
                                          intercom.destination!.longitude,
                                          intercom.destination!.title,
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00A8CC),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                intercom.destination!.title,
                                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Icon(Icons.location_on, size: 36, color: Colors.amberAccent),
                                          ],
                                        ),
                                      ),
                                    ),
                                  // Rider Markers
                                  ...intercom.telemetries.values.map((t) {
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
                                  }),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Fit all riders button
                                FloatingActionButton.small(
                                  heroTag: 'btn_fit_all',
                                  backgroundColor: const Color(0xFF1E293B),
                                  tooltip: 'Fit All Riders & Destination',
                                  onPressed: () => _fitAllRidersAndDestination(intercom),
                                  child: const Icon(Icons.zoom_out_map, color: Color(0xFF00A8CC), size: 18),
                                ),
                                const SizedBox(height: 8),
                                // Center on self
                                FloatingActionButton.small(
                                  heroTag: 'btn_center_self',
                                  backgroundColor: const Color(0xFF1E293B),
                                  tooltip: 'Center on Me',
                                  onPressed: () {
                                    _mapController.move(centerLatLng, 15.0);
                                  },
                                  child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                                ),
                              ],
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

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (t != null && t.latitude != 0.0) {
                              _focusOnRider(t.latitude, t.longitude);
                            } else if (participant is LocalParticipant && intercom.currentPosition != null) {
                              _focusOnRider(
                                intercom.currentPosition!.latitude,
                                intercom.currentPosition!.longitude,
                              );
                            }
                          },
                          child: Container(
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              participant.name.isNotEmpty ? participant.name : participant.identity,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (t != null && t.latitude != 0.0)
                                            const Icon(Icons.map_outlined, size: 14, color: Color(0xFF00A8CC)),
                                        ],
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
                              Row(
                                children: [
                                  // Open Rider's current location in Navigation App
                                  if (t != null && participant is! LocalParticipant)
                                    IconButton(
                                      icon: const Icon(Icons.directions, color: Color(0xFF00A8CC), size: 20),
                                      tooltip: 'Navigate to ${participant.name}',
                                      onPressed: () => _openNavigationApp(
                                        t.latitude,
                                        t.longitude,
                                        participant.name,
                                      ),
                                    ),

                                  // Whisper / 1-on-1 Private Talk trigger
                                  if (participant is! LocalParticipant)
                                    IconButton(
                                      icon: Icon(
                                        intercom.privateTalkTargetId == participant.identity
                                            ? Icons.record_voice_over
                                            : Icons.hearing,
                                        color: intercom.privateTalkTargetId == participant.identity
                                            ? Colors.purpleAccent
                                            : Colors.white54,
                                        size: 22,
                                      ),
                                      tooltip: intercom.privateTalkTargetId == participant.identity
                                          ? 'End 1-on-1 Whisper'
                                          : 'Start 1-on-1 Private Talk',
                                      onPressed: () {
                                        if (intercom.privateTalkTargetId == participant.identity) {
                                          intercom.setPrivateTalkTarget(null, null);
                                        } else {
                                          intercom.setPrivateTalkTarget(
                                            participant.identity,
                                            participant.name.isNotEmpty ? participant.name : participant.identity,
                                          );
                                        }
                                      },
                                    ),

                                  if (isSpeaking)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.volume_up, color: Colors.greenAccent),
                                    ),
                                ],
                              ),
                            ],
                          ),
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
