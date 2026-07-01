import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/plugin_info.dart';
import '../models/privacy_manifest_status.dart';

/// Native API symbols whose use requires a PrivacyInfo.xcprivacy "required reason" entry.
/// See: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api
const _requiredReasonSymbols = [
  // NSUserDefaults
  'NSUserDefaults', 'UserDefaults',
  // File timestamps
  'NSFileCreationDate', 'NSFileModificationDate',
  'NSURLContentModificationDateKey', 'NSURLCreationDateKey',
  // Disk space
  'NSFileSystemFreeSize', 'NSFileSystemSize',
  'volumeAvailableCapacityForImportantUsage',
  'volumeAvailableCapacityForOpportunisticUsage',
  // System boot time
  'systemUptime', 'NSProcessInfoThermalState',
  // Active keyboard
  'activeInputModes',
];

class PubCacheScanner {
  /// knownDb is the parsed packages list from known_privacy_manifest_status.json
  final List<Map<String, dynamic>> knownDb;

  PubCacheScanner(this.knownDb);

  /// Checks a single plugin across three tiers and returns its [PrivacyManifestStatus].
  Future<PrivacyManifestStatus> checkPlugin(PluginInfo plugin) async {
    final pubDevUrl = 'https://pub.dev/packages/${plugin.name}';

    if (!plugin.isNativePlugin) {
      return PrivacyManifestStatus(
        pluginName: plugin.name,
        version: plugin.version,
        presence: ManifestPresence.unknown,
        detectionTier: PrivacyManifestTier.unknown,
        note: 'Pure Dart package — no native iOS/macOS code detected.',
        pubDevUrl: pubDevUrl,
      );
    }

    final suspectedApi = await _checkRequiredReasonHeuristic(plugin.path);

    // Tier 1 — local file scan
    final localResult = await _scanLocalManifest(plugin.path);
    if (localResult != null) {
      return PrivacyManifestStatus(
        pluginName: plugin.name,
        version: plugin.version,
        presence: ManifestPresence.present,
        detectionTier: PrivacyManifestTier.localFile,
        suspectedRequiredReasonApi: suspectedApi,
        manifestPath: localResult,
        pubDevUrl: pubDevUrl,
      );
    }

    // Tier 2 — known database
    final dbEntry = _lookupDb(plugin.name);
    if (dbEntry != null) {
      final hasManifest = dbEntry['hasManifest'] as bool? ?? false;
      return PrivacyManifestStatus(
        pluginName: plugin.name,
        version: plugin.version,
        presence:
            hasManifest ? ManifestPresence.present : ManifestPresence.missing,
        detectionTier: PrivacyManifestTier.knownDatabase,
        suspectedRequiredReasonApi: suspectedApi,
        note: dbEntry['note'] as String?,
        pubDevUrl: pubDevUrl,
      );
    }

    // Tier 3 — unknown
    return PrivacyManifestStatus(
      pluginName: plugin.name,
      version: plugin.version,
      presence: ManifestPresence.unknown,
      detectionTier: PrivacyManifestTier.unknown,
      suspectedRequiredReasonApi: suspectedApi,
      note: 'Not in database — verify manually.',
      pubDevUrl: pubDevUrl,
    );
  }

  /// Returns the path of the first .xcprivacy file found, or null.
  Future<String?> _scanLocalManifest(String? basePath) async {
    if (basePath == null) return null;
    for (final sub in ['ios', 'macos']) {
      final dir = Directory(p.join(basePath, sub));
      if (!dir.existsSync()) continue;
      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.endsWith('.xcprivacy')) {
            return entity.path;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<bool> _checkRequiredReasonHeuristic(String? basePath) async {
    if (basePath == null) return false;
    final extensions = {'.swift', '.m', '.mm', '.h'};
    try {
      await for (final entity
          in Directory(basePath).list(recursive: true, followLinks: false)) {
        if (entity is File && extensions.contains(p.extension(entity.path))) {
          try {
            final content = await entity.readAsString(encoding: utf8);
            for (final sym in _requiredReasonSymbols) {
              if (content.contains(sym)) return true;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return false;
  }

  Map<String, dynamic>? _lookupDb(String packageName) {
    try {
      return knownDb.firstWhere((e) => e['package'] == packageName);
    } catch (_) {
      return null;
    }
  }
}
