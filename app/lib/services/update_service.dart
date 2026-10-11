import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
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

  String get downloadUrl => id > 0
      ? 'https://edar.nexkod.com/p/$projectId/download/$id'
      : 'https://edar.nexkod.com/p/$projectId/download/latest';
  String get portalUrl => 'https://edar.nexkod.com/p/$projectId';

  String get fileSizeFormatted {
    if (fileSizeBytes <= 0) return '';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}


class UpdateCheckResult {
  final bool hasUpdate;
  final int currentCode;
  final NexEdarRelease? release;
  final String? error;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.currentCode,
    this.release,
    this.error,
  });
}

class UpdateService {
  /// Fetches the latest published release on NexEdar
  static Future<NexEdarRelease?> checkLatestRelease({String projectId = 'nexronda'}) async {
    try {
      // 1. Try /latest endpoint first
      final latestUrl = Uri.parse('https://edar.nexkod.com/api/v1/apps/$projectId/latest');
      final res = await http.get(latestUrl).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data.containsKey('version_code')) {
          // Flatten into NexEdarRelease
          return NexEdarRelease(
            id: (data['id'] as num?)?.toInt() ?? 0,
            projectId: data['project_id'] as String? ?? projectId,
            versionName: data['version_name'] as String? ?? '1.0.0',
            versionCode: (data['version_code'] as num?)?.toInt() ?? 1,
            fileSizeBytes: (data['file_size'] as num?)?.toInt() ?? 0,
            sha256: data['sha256'] as String? ?? '',
            changelog: data['changelog'] as String? ?? '',
            isMandatory: data['is_mandatory'] as bool? ?? false,
            createdAt: data['published_at'] as String? ?? '',
          );
        }
      }

      // 2. Fallback to /releases endpoint
      final releasesUrl = Uri.parse('https://edar.nexkod.com/api/v1/apps/$projectId/releases');
      final resList = await http.get(releasesUrl).timeout(const Duration(seconds: 4));
      if (resList.statusCode == 200) {
        final data = jsonDecode(resList.body) as Map<String, dynamic>;
        final releases = data['releases'] as List<dynamic>?;
        if (releases != null && releases.isNotEmpty) {
          return NexEdarRelease.fromJson(releases.first as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] checkLatestRelease error: $e');
    }
    return null;
  }

  /// Checks if an update is available compared to the currently running version
  static Future<UpdateCheckResult> checkUpdateStatus() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final rawCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      // Flutter's --split-per-abi adds an ABI offset to Android versionCode:
      // 1000 for armeabi-v7a, 2000 for arm64-v8a, 3000 for x86_64.
      // So build +7 on arm64 becomes 2007 in PackageInfo.buildNumber.
      // Modulo 1000 retrieves the true logical buildNumber.
      final currentCode = rawCode >= 1000 ? (rawCode % 1000) : rawCode;

      final latest = await checkLatestRelease();
      if (latest != null) {
        return UpdateCheckResult(
          hasUpdate: latest.versionCode > currentCode,
          currentCode: currentCode,
          release: latest,
        );
      }
      return UpdateCheckResult(
        hasUpdate: false,
        currentCode: currentCode,
        error: 'Unable to connect to NexEdar server',
      );
    } catch (e) {
      debugPrint('[UpdateService] Error checking update: $e');
      return UpdateCheckResult(
        hasUpdate: false,
        currentCode: 1,
        error: e.toString(),
      );
    }
  }

  static Future<NexEdarRelease?> checkForUpdate() async {
    final status = await checkUpdateStatus();
    if (status.hasUpdate) return status.release;
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

              try {
                final launched = await launchUrl(
                  targetUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) {
                  // Fallback without mode
                  await launchUrl(targetUrl);
                }
              } catch (e) {
                debugPrint('[UpdateService] Failed to launch update URL: $e');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Could not open download link: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
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
