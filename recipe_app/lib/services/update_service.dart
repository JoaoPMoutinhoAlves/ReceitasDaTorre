import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Details about a newer release available on GitHub.
class UpdateInfo {
  final String latestVersion; // normalized "x.y.z"
  final String tagName;
  final String? apkUrl; // browser_download_url of the .apk asset
  final String releaseUrl; // GitHub release page
  final String? releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.apkUrl,
    required this.releaseUrl,
    required this.releaseNotes,
  });

  bool get canInstall => apkUrl != null && apkUrl!.isNotEmpty;
}

/// Checks GitHub Releases for a newer build of the sideloaded APK and
/// drives the download + install flow.
class UpdateService {
  static const String _repo = 'JoaoPMoutinhoAlves/ReceitasDaTorre';
  static const String _dismissedKey = 'dismissed_update_version';

  // ─── Current version ────────────────────────────────────────────────────────

  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version; // e.g. "1.0.0"
  }

  // ─── Check GitHub for the latest release ────────────────────────────────────

  /// Returns an [UpdateInfo] when the latest GitHub release is newer than the
  /// running version, otherwise `null` (already up to date, offline, or no
  /// parsable release).
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final latest =
          _extractVersion(tag) ?? _extractVersion((data['name'] as String?) ?? '');
      if (latest == null) return null;

      final current = await currentVersion();
      if (!_isNewer(latest, current)) return null;

      // Find the first asset whose filename ends in .apk
      String? apkUrl;
      final assets = (data['assets'] as List<dynamic>?) ?? const [];
      for (final a in assets) {
        final name = ((a as Map<String, dynamic>)['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        latestVersion: latest,
        tagName: tag,
        apkUrl: apkUrl,
        releaseUrl: (data['html_url'] as String?) ?? 'https://github.com/$_repo/releases',
        releaseNotes: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── "Don't ask again" state (for the non-mandatory popup) ───────────────────

  /// Whether the auto popup for [version] was already dismissed by the user.
  /// Settings always shows the update regardless of this flag.
  static Future<bool> isDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedKey) == version;
  }

  static Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }

  // ─── Install ─────────────────────────────────────────────────────────────────

  /// Downloads the APK and launches Android's package installer.
  /// Emits progress events; throws if [info] has no APK asset.
  static Stream<OtaEvent> install(UpdateInfo info) {
    if (!info.canInstall) {
      throw StateError('No APK asset attached to release ${info.tagName}');
    }
    return OtaUpdate().execute(
      info.apkUrl!,
      destinationFilename: 'receitas-${info.latestVersion}.apk',
    );
  }

  // ─── Version helpers ─────────────────────────────────────────────────────────

  /// Pulls the first "x.y.z" looking token out of an arbitrary string
  /// (handles tags like "v1.0.1", "app-v1.0.1", "Release 1.0.1").
  static String? _extractVersion(String s) {
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(s);
    return m?.group(0);
  }

  static List<int> _components(String v) {
    final clean = _extractVersion(v) ?? '0.0.0';
    return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  static bool _isNewer(String latest, String current) {
    final a = _components(latest);
    final b = _components(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }
}
