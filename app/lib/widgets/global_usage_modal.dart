import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/intercom_service.dart';

class GlobalUsageModal extends StatefulWidget {
  const GlobalUsageModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const GlobalUsageModal(),
    );
  }

  @override
  State<GlobalUsageModal> createState() => _GlobalUsageModalState();
}

class _GlobalUsageModalState extends State<GlobalUsageModal> {
  late Future<GlobalUsageStats> _usageFuture;

  @override
  void initState() {
    super.initState();
    _usageFuture = ApiService.getUsage();
  }

  void _refresh() {
    setState(() {
      _usageFuture = ApiService.getUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A8CC).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.cloud_sync, color: Color(0xFF00A8CC), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LiveKit Cloud & Network Usage',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Global SFU capacity & participant limits',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                  tooltip: 'Refresh Stats',
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            FutureBuilder<GlobalUsageStats>(
              future: _usageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A8CC)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load usage stats:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  );
                }

                final stats = snapshot.data!;
                final usageRatio = (stats.activeParticipants / stats.maxParticipants).clamp(0.0, 1.0);

                return Column(
                  children: [
                    // Concurrency Gauge Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CONCURRENT RIDERS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: Colors.white60,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stats.status == 'healthy'
                                      ? Colors.greenAccent.withValues(alpha: 0.15)
                                      : Colors.amberAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stats.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: stats.status == 'healthy'
                                        ? Colors.greenAccent
                                        : Colors.amberAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${stats.activeParticipants}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00A8CC),
                                ),
                              ),
                              Text(
                                ' / ${stats.maxParticipants} max limit',
                                style: const TextStyle(fontSize: 14, color: Colors.white54),
                              ),
                              const Spacer(),
                              Text(
                                '${(usageRatio * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: usageRatio > 0.8 ? Colors.amberAccent : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: usageRatio,
                              minHeight: 8,
                              backgroundColor: Colors.white12,
                              color: usageRatio > 0.8
                                  ? Colors.redAccent
                                  : usageRatio > 0.5
                                      ? Colors.amberAccent
                                      : const Color(0xFF00A8CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metrics Grid
                    Row(
                      children: [
                        // Active Convoys
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.hub, color: Colors.amberAccent, size: 16),
                                    SizedBox(width: 6),
                                    Text('ACTIVE ROOMS', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${stats.activeRooms}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${stats.registeredRooms} total registered',
                                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Monthly Bandwidth Limit
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.speed, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 6),
                                    Text('CLOUD QUOTA', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${stats.maxBandwidthGb.toInt()} GB',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'Monthly SFU quota',
                                  style: TextStyle(fontSize: 10, color: Colors.white38),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Live Rider Cellular Data & Bitrate Counter
                    Consumer<IntercomService>(
                      builder: (context, intercom, _) {
                        final isConnected = intercom.state == IntercomState.connected;
                        final mbUsed = (intercom.totalSessionBytes / (1024 * 1024));
                        final bitrate = intercom.currentBitrateKbps;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF00A8CC).withValues(alpha: 0.5)
                                  : Colors.white10,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.network_check,
                                    size: 16,
                                    color: isConnected ? Colors.cyanAccent : Colors.white38,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'THIS DEVICE / SESSION DATA',
                                    style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                  ),
                                  const Spacer(),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isConnected ? Colors.greenAccent : Colors.white24,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isConnected ? 'LIVE' : 'STANDBY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isConnected ? Colors.greenAccent : Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mbUsed < 0.1
                                            ? '${(intercom.totalSessionBytes / 1024).toStringAsFixed(1)} KB'
                                            : '${mbUsed.toStringAsFixed(2)} MB',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        'Cellular data consumed',
                                        style: TextStyle(fontSize: 10, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${bitrate.toStringAsFixed(1)} kbps',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: bitrate > 0 ? Colors.greenAccent : Colors.white54,
                                        ),
                                      ),
                                      const Text(
                                        'Live audio & GPS bitrate',
                                        style: TextStyle(fontSize: 10, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Plan Info footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 16, color: Color(0xFF00A8CC)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${stats.plan} • High-availability Opus audio SFU',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }
}
