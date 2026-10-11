import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class NexEdarRelease {
  final int id;
  final String projectId;
  final String versionName;
  final int versionCode;
  final int fileSizeBytes;
  final String sha256;
  final String changelog;
  final bool isMandatory;
  final String createdAt;

  NexEdarRelease({
    required this.id,
    required this.projectId,
    required this.versionName,
    required this.versionCode,
    required this.fileSizeBytes,
    required this.sha256,
    required this.changelog,
    required this.isMandatory,
    required this.createdAt,
  });

  factory NexEdarRelease.fromJson(Map<String, dynamic> json) {
    return NexEdarRelease(
      id: (json['id'] as num).toInt(),
      projectId: json['project_id'] as String? ?? 'nexronda',
      versionName: json['version_name'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get downloadUrl => 'https://edar.nexkod.com/p/$projectId/download/$id';
  String get portalUrl => 'https://edar.nexkod.com/p/$projectId';

  String get fileSizeFormatted {
    if (fileSizeBytes <= 0) return '';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static const int currentVersionCode = 2; // Matches pubspec.yaml versionCode
  static const String currentVersionName = '1.0.0';

  /// Fetches the latest published release on NexEdar
  static Future<NexEdarRelease?> checkLatestRelease({String projectId = 'nexronda'}) async {
    try {
      final url = Uri.parse('https://edar.nexkod.com/api/v1/apps/$projectId/releases');
      final res = await http.get(url).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final releases = data['releases'] as List<dynamic>?;
        if (releases != null && releases.isNotEmpty) {
          // The first release is the newest (sorted by ID DESC)
          return NexEdarRelease.fromJson(releases.first as Map<String, dynamic>);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Checks if an update is available compared to the currently running version
  static Future<NexEdarRelease?> checkForUpdate() async {
    final latest = await checkLatestRelease();
    if (latest != null && latest.versionCode > currentVersionCode) {
      return latest;
    }
    return null;
  }

  /// Prompts the user with an In-App Update dialog
  static Future<void> showUpdateDialog(BuildContext context, NexEdarRelease release) async {
    return showDialog(
      context: context,
      barrierDismissible: !release.isMandatory,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00A8CC).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update, color: Color(0xFF00A8CC), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Update Available',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A8CC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'v${release.versionName}+${release.versionCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                ),
                if (release.fileSizeFormatted.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    release.fileSizeFormatted,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              "What's New:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                release.changelog.isNotEmpty ? release.changelog : 'General improvements and bug fixes.',
                style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              !kIsWeb && Platform.isAndroid
                  ? 'Tap "UPDATE NOW" to download and install the latest APK directly from NexEdar.'
                  : 'Tap "VIEW RELEASE" to open the NexEdar portal.',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
        actions: [
          if (!release.isMandatory)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('LATER', style: TextStyle(color: Colors.white54)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8CC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download, size: 18),
            label: Text(
              !kIsWeb && Platform.isAndroid ? 'UPDATE NOW' : 'VIEW RELEASE',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final targetUrl = !kIsWeb && Platform.isAndroid
                  ? Uri.parse(release.downloadUrl)
                  : Uri.parse(release.portalUrl);

              if (await canLaunchUrl(targetUrl)) {
                await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
              }
              if (ctx.mounted && !release.isMandatory) {
                Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}
