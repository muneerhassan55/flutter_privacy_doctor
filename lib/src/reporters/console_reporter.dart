import '../models/privacy_manifest_status.dart';
import '../services/android_manifest_parser.dart';
import '../services/data_collection_service.dart';
import '../disclaimers.dart';

const _reset = '\x1B[0m';
const _bold = '\x1B[1m';
const _green = '\x1B[32m';
const _red = '\x1B[31m';
const _yellow = '\x1B[33m';
const _cyan = '\x1B[36m';
const _dim = '\x1B[2m';

class ConsoleReporter {
  final bool useColor;
  ConsoleReporter({this.useColor = true});

  String _c(String text, String code) => useColor ? '$code$text$_reset' : text;

  void printHeader(String title) {
    final line = '━' * 60;
    print('\n${_c(line, _cyan)}');
    print(_c('  $title', _bold));
    print('${_c(line, _cyan)}\n');
  }

  void printManifests(List<PrivacyManifestStatus> statuses) {
    printHeader('iOS / macOS Privacy Manifest Check');

    final native = statuses
        .where((s) =>
            s.detectionTier != PrivacyManifestTier.unknown ||
            s.presence != ManifestPresence.unknown)
        .toList();
    final pureDart = statuses
        .where((s) =>
            s.detectionTier == PrivacyManifestTier.unknown &&
            s.presence == ManifestPresence.unknown &&
            (s.note?.contains('Pure Dart') ?? false))
        .toList();

    if (native.isEmpty && pureDart.isEmpty) {
      print(_c('  No native iOS/macOS plugins detected.', _dim));
      return;
    }

    for (final s in statuses) {
      _printManifestRow(s);
    }

    _printManifestSummary(statuses);
  }

  void _printManifestRow(PrivacyManifestStatus s) {
    String icon;
    String color;
    if (s.note?.contains('Pure Dart') ?? false) {
      icon = '⬜';
      color = _dim;
    } else {
      switch (s.presence) {
        case ManifestPresence.present:
          icon = '✅';
          color = _green;
        case ManifestPresence.missing:
          icon = '❌';
          color = _red;
        case ManifestPresence.unknown:
          icon = '❓';
          color = _yellow;
      }
    }

    final tier = s.detectionTier == PrivacyManifestTier.localFile
        ? ' ${_c('[local file]', _dim)}'
        : s.detectionTier == PrivacyManifestTier.knownDatabase
            ? ' ${_c('[database]', _dim)}'
            : '';

    print('  $icon ${_c(s.pluginName, color)} @${s.version}$tier');

    if (s.suspectedRequiredReasonApi) {
      print(_c(
          '      ⚠️  Heuristic: likely uses Required Reason API — manifest is mandatory',
          _yellow));
    }
    if (s.note != null && !(s.note!.contains('Pure Dart'))) {
      print(_c('      ℹ  ${s.note}', _dim));
    }
    if (s.presence == ManifestPresence.unknown ||
        s.presence == ManifestPresence.missing) {
      print(_c('      🔗 ${s.pubDevUrl}', _dim));
    }
  }

  void _printManifestSummary(List<PrivacyManifestStatus> statuses) {
    final present =
        statuses.where((s) => s.presence == ManifestPresence.present).length;
    final missing =
        statuses.where((s) => s.presence == ManifestPresence.missing).length;
    final unknown = statuses
        .where((s) =>
            s.presence == ManifestPresence.unknown &&
            !(s.note?.contains('Pure Dart') ?? false))
        .length;

    print('');
    print(
        '${_c('  Summary: ', _bold)}${_c('$present ✅ present', _green)}  ${_c('$missing ❌ missing', _red)}  ${_c('$unknown ❓ unknown', _yellow)}');
  }

  void printDataLabels(List<DataCollectionResult> results) {
    printHeader('Draft Privacy Labels (App Store & Play Store)');

    final inDb = results.where((r) => r.isInDatabase).toList();
    final notInDb = results
        .where((r) => !r.isInDatabase && r.plugin.isNativePlugin)
        .toList();

    if (inDb.isEmpty) {
      print(_c(
          '  None of your dependencies were found in the database.', _yellow));
    }

    for (final result in inDb) {
      final entry = result.entry!;
      print(
          '\n  ${_c('📦 ${entry.sdkName}', _bold)}  ${_c(entry.description, _dim)}');
      print(_c('  ─────────────────────────────', _dim));

      for (final cat in entry.dataCategories) {
        final tracking = cat.usedForTracking ? _c(' [TRACKING]', _red) : '';
        final linked =
            cat.linkedToIdentity ? _c(' [linked to identity]', _yellow) : '';
        print(
            '    🍎 ${cat.appStoreCategory} › ${cat.appStoreDataType}$linked$tracking');
        print('    🤖 ${cat.playStoreCategory} › ${cat.playStoreDataType}');
        print(_c('       Purposes: ${cat.purpose.join(', ')}', _dim));
      }
      print(_c('    📎 Citation: ${entry.citationUrl}', _dim));
    }

    if (notInDb.isNotEmpty) {
      print('\n  ${_c('⚠️  Not in database — check manually:', _yellow)}');
      for (final r in notInDb) {
        print('    ❓ ${r.plugin.name} @${r.plugin.version}');
        print(_c('       https://pub.dev/packages/${r.plugin.name}', _dim));
      }
    }
  }

  void printAndroidPermissions(List<PermissionInfo> permissions) {
    printHeader('Android Permissions → Play Store Data Safety');

    if (permissions.isEmpty) {
      print(_c(
          '  No AndroidManifest.xml found or no permissions declared.', _dim));
      return;
    }

    final mapped = permissions.where((p) => p.hasMappedCategory).toList();
    final unmapped = permissions.where((p) => !p.hasMappedCategory).toList();

    if (mapped.isNotEmpty) {
      print(_c('  Permissions with Data Safety mapping:', _bold));
      for (final perm in mapped) {
        print('  🔹 ${_c(perm.permission.split('.').last, _cyan)}');
        print('     → ${perm.playStoreCategory} › ${perm.playStoreDataType}');
        if (perm.note != null) print(_c('     ℹ  ${perm.note}', _dim));
      }
    }

    if (unmapped.isNotEmpty) {
      print('\n  ${_c('Standard / no direct Data Safety mapping:', _dim)}');
      for (final perm in unmapped) {
        print(_c('  ⬜ ${perm.permission.split('.').last}', _dim));
      }
    }
  }

  void printFooter() {
    print('\n${_c(Disclaimers.full, _yellow)}\n');
  }

  void printDivider() {
    print(_c('─' * 60, _dim));
  }
}
