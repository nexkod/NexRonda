import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  final String? directDownloadUrl;

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
    this.directDownloadUrl,
  });

  factory NexEdarRelease.fromJson(Map<String, dynamic> json) {
    return NexEdarRelease(
      id: (json['id'] as num?)?.toInt() ?? 0,
      projectId: json['project_id'] as String? ?? 'nexronda',
      versionName: json['version_name'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? (json['file_size'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      changelog: json['changelog'] as String? ?? '',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? json['published_at'] as String? ?? '',
      directDownloadUrl: json['download_url'] as String?,
    );
  }

  String get downloadUrl {
    if (directDownloadUrl != null && directDownloadUrl!.isNotEmpty) {
      return directDownloadUrl!;
    }
    if (id > 0) {
      return 'https://edar.nexkod.com/p/$projectId/download/$id';
    }
    return 'https://edar.nexkod.com/p/$projectId';
  }

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
          return NexEdarRelease.fromJson(data);
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
      builder: (ctx) => _UpdateDialog(release: release),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final NexEdarRelease release;

  const _UpdateDialog({required this.release});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  http.Client? _client;

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _startInAppDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.release.fileSizeBytes;
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.release.downloadUrl));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode})');
      }

      final contentLength = response.contentLength ?? widget.release.fileSizeBytes;
      if (contentLength > 0) {
        setState(() => _totalBytes = contentLength);
      }

      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/nexronda_update_v${widget.release.versionCode}.apk');
      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();

      await for (final chunk in response.stream) {
        if (!mounted) {
          await sink.close();
          return;
        }
        sink.add(chunk);
        _receivedBytes += chunk.length;
        if (_totalBytes > 0) {
          setState(() {
            _progress = (_receivedBytes / _totalBytes).clamp(0.0, 1.0);
          });
        }
      }

      await sink.flush();
      await sink.close();

      if (!mounted) return;

      // Automatically launch the APK installer
      final result = await OpenFilex.open(
        saveFile.path,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint('[UpdateService] OpenFilex result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Could not start installer automatically: ${result.message}';
          });
        }
      } else {
        if (mounted && !widget.release.isMandatory) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Download error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Download failed: $e';
          _isDownloading = false;
        });
      }
    } finally {
      if (mounted && _errorMessage == null) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final receivedMb = (_receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (_totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final percentage = (_progress * 100).toInt();

    return AlertDialog(
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
          if (!_isDownloading && _errorMessage == null) ...[
            const Text(
              "What's New:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  release.changelog.isNotEmpty ? release.changelog : 'General improvements and bug fixes.',
                  style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ),
            ),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Downloading update...',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(color: Color(0xFF00A8CC), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _totalBytes > 0 ? _progress : null,
                minHeight: 8,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A8CC)),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _totalBytes > 0 ? '$receivedMb MB / $totalMb MB' : '$receivedMb MB',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            !kIsWeb && Platform.isAndroid
                ? (_isDownloading
                    ? 'The installer will automatically open when complete.'
                    : 'Download progress will show in-app and launch install automatically.')
                : 'Tap "VIEW RELEASE" to open the NexEdar portal.',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
      actions: [
        if (!release.isMandatory && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('LATER', style: TextStyle(color: Colors.white54)),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8CC),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(_errorMessage != null ? Icons.refresh : Icons.download, size: 18),
            label: Text(
              !kIsWeb && Platform.isAndroid
                  ? (_errorMessage != null ? 'RETRY' : 'UPDATE NOW')
                  : 'VIEW RELEASE',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              if (!kIsWeb && Platform.isAndroid) {
                await _startInAppDownload();
              } else {
                final targetUrl = Uri.parse(release.portalUrl);
                try {
                  await launchUrl(targetUrl, mode: LaunchMode.externalApplication);
                } catch (_) {
                  await launchUrl(targetUrl);
                }
                if (context.mounted && !release.isMandatory) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
      ],
    );
  }
}
