import 'dart:io';
import '../models/privacy_manifest_status.dart';
import '../services/android_manifest_parser.dart';
import '../services/data_collection_service.dart';
import '../disclaimers.dart';

class MarkdownExportReporter {
  static void export({
    required String filePath,
    required List<PrivacyManifestStatus> manifestStatuses,
    required List<DataCollectionResult> dataResults,
    required List<PermissionInfo> androidPermissions,
    String? projectName,
  }) {
    final buf = StringBuffer();
    final date = DateTime.now().toIso8601String().split('T').first;

    buf.writeln('# Privacy Compliance Draft Report');
    if (projectName != null) buf.writeln('**Project:** `$projectName`  ');
    buf.writeln('**Generated:** $date by flutter_privacy_doctor  ');
    buf.writeln();
    buf.writeln(Disclaimers.markdownBlock);
    buf.writeln();

    // ── iOS / macOS Privacy Manifests ───────────────────────────────────────
    buf.writeln('## iOS / macOS Privacy Manifest Check');
    buf.writeln();
    buf.writeln('| Package | Version | Manifest | Detection | Notes |');
    buf.writeln('|---------|---------|----------|-----------|-------|');

    for (final s in manifestStatuses) {
      String icon;
      switch (s.presence) {
        case ManifestPresence.present:
          icon = '✅';
        case ManifestPresence.missing:
          icon = '❌';
        case ManifestPresence.unknown:
          icon = '❓';
      }

      final tier = switch (s.detectionTier) {
        PrivacyManifestTier.localFile => 'Local file',
        PrivacyManifestTier.knownDatabase => 'Database',
        PrivacyManifestTier.unknown => '—',
      };

      final apiWarn = s.suspectedRequiredReasonApi ? ' ⚠️ req-reason API' : '';
      final note = (s.note ?? '') + apiWarn;

      buf.writeln(
          '| [${s.pluginName}](${s.pubDevUrl}) | ${s.version} | $icon | $tier | ${_mdEscape(note)} |');
    }

    buf.writeln();

    // ── App Store Privacy Nutrition Labels ──────────────────────────────────
    buf.writeln('## App Store Privacy Nutrition Label — Draft');
    buf.writeln('_Mirror of Apple\'s privacy label categories._');
    buf.writeln();

    final inDb = dataResults.where((r) => r.isInDatabase).toList();
    final notInDb = dataResults
        .where((r) => !r.isInDatabase && r.plugin.isNativePlugin)
        .toList();

    if (inDb.isEmpty) {
      buf.writeln('_No dependencies matched the database._');
    } else {
      buf.writeln(
          '| SDK | Data Category | Data Type | Linked to Identity | For Tracking | Purposes |');
      buf.writeln(
          '|-----|--------------|-----------|-------------------|--------------|----------|');

      for (final result in inDb) {
        final entry = result.entry!;
        for (final cat in entry.dataCategories) {
          buf.writeln(
              '| ${entry.sdkName} | ${cat.appStoreCategory} | ${cat.appStoreDataType} | ${cat.linkedToIdentity ? 'Yes' : 'No'} | ${cat.usedForTracking ? 'Yes ⚠️' : 'No'} | ${cat.purpose.join(', ')} |');
        }
      }
    }

    buf.writeln();

    // ── Google Play Data Safety ─────────────────────────────────────────────
    buf.writeln('## Google Play Data Safety Form — Draft');
    buf.writeln('_Mirror of Google Play Data Safety categories._');
    buf.writeln();

    if (inDb.isNotEmpty) {
      buf.writeln(
          '| SDK | Data Category | Data Type | Linked to Identity | For Tracking | Purposes |');
      buf.writeln(
          '|-----|--------------|-----------|-------------------|--------------|----------|');

      for (final result in inDb) {
        final entry = result.entry!;
        for (final cat in entry.dataCategories) {
          buf.writeln(
              '| ${entry.sdkName} | ${cat.playStoreCategory} | ${cat.playStoreDataType} | ${cat.linkedToIdentity ? 'Yes' : 'No'} | ${cat.usedForTracking ? 'Yes ⚠️' : 'No'} | ${cat.purpose.join(', ')} |');
        }
      }
    }

    buf.writeln();

    if (notInDb.isNotEmpty) {
      buf.writeln('## ⚠️ Not in Database — Manual Review Required');
      buf.writeln();
      buf.writeln(
          'These native plugins were not found in the data collection database. '
          'Check each SDK\'s own privacy documentation before submitting.');
      buf.writeln();
      for (final r in notInDb) {
        buf.writeln(
            '- ❓ **${r.plugin.name}** @${r.plugin.version} — [pub.dev](https://pub.dev/packages/${r.plugin.name})');
      }
      buf.writeln();
    }

    // ── Android Permissions ─────────────────────────────────────────────────
    buf.writeln('## Android Permissions → Play Store Data Safety');
    buf.writeln();

    if (androidPermissions.isEmpty) {
      buf.writeln(
          '_AndroidManifest.xml not found or no permissions declared._');
    } else {
      buf.writeln('| Permission | Play Store Category | Data Type | Notes |');
      buf.writeln('|------------|--------------------|-----------| ------|');
      for (final perm in androidPermissions) {
        buf.writeln(
            '| `${perm.permission}` | ${perm.playStoreCategory ?? '—'} | ${perm.playStoreDataType ?? '—'} | ${_mdEscape(perm.note ?? '')} |');
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln(
        '_Generated by [flutter\\_privacy\\_doctor](https://pub.dev/packages/flutter_privacy_doctor). '
        'See also: [flutter\\_spm\\_doctor](https://pub.dev/packages/flutter_spm_doctor)._');

    final outFile = File(filePath);
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(buf.toString());
  }

  static String _mdEscape(String s) =>
      s.replaceAll('|', '\\|').replaceAll('\n', ' ');
}
