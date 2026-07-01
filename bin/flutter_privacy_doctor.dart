import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_privacy_doctor/flutter_privacy_doctor.dart';
import 'package:flutter_privacy_doctor/src/services/data_collection_service.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help.')
    ..addFlag('json', negatable: false, help: 'Output as JSON (for CI).')
    ..addFlag('fail-on-missing-manifest',
        negatable: false,
        help:
            'Exit with code 1 if any native dependency is missing a manifest.')
    ..addOption('ignore',
        help: 'Comma-separated list of package names to ignore.')
    ..addOption('export',
        help: 'Path to write a Markdown report (e.g. privacy_report.md).')
    ..addOption('project',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to Flutter project root (default: current directory).');

  // Sub-commands
  final manifestsParser = ArgParser();
  final dataLabelsParser = ArgParser();
  final androidParser = ArgParser();

  parser
    ..addCommand('manifests', manifestsParser)
    ..addCommand('data-labels', dataLabelsParser)
    ..addCommand('android-permissions', androidParser);

  ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    _die('Error: ${e.message}\n\n${_usage(parser)}');
  }

  if (results['help'] as bool) {
    print(_usage(parser));
    exit(0);
  }

  final projectDir = p.canonicalize(results['project'] as String);
  final useJson = results['json'] as bool;
  final failOnMissing = results['fail-on-missing-manifest'] as bool;
  final ignoreSet = _parseIgnore(results['ignore'] as String?);
  final exportPath = results['export'] as String?;
  final subCommand = results.command?.name;

  _checkProject(projectDir);

  // ── Load plugins ────────────────────────────────────────────────────────
  final List<PluginInfo> allPlugins;
  try {
    allPlugins = await PubspecReader.getResolvedPlugins(projectDir);
  } catch (e) {
    _die('Could not read dependencies: $e');
  }

  final plugins = allPlugins.where((p) => !ignoreSet.contains(p.name)).toList();

  // ── Load databases ──────────────────────────────────────────────────────
  final manifestDb = _loadManifestDb();
  final scanner = PubCacheScanner(manifestDb);
  final dataService = _loadDataService();

  // ── Run analysis ────────────────────────────────────────────────────────
  final runManifests = subCommand == null || subCommand == 'manifests';
  final runDataLabels = subCommand == null || subCommand == 'data-labels';
  final runAndroid = subCommand == null || subCommand == 'android-permissions';

  List<PrivacyManifestStatus> manifestStatuses = [];
  List<DataCollectionResult> dataResults = [];
  List<PermissionInfo> permissions = [];

  if (runManifests) {
    final nativePlugins = plugins.where((p) => p.isNativePlugin).toList();
    for (final plugin in nativePlugins) {
      manifestStatuses.add(await scanner.checkPlugin(plugin));
    }
  }

  if (runDataLabels) {
    dataResults = dataService.crossReference(plugins);
  }

  if (runAndroid) {
    permissions =
        await AndroidManifestParser.getDeclaredPermissions(projectDir);
  }

  // ── Output ──────────────────────────────────────────────────────────────
  if (useJson) {
    final json = JsonReporter.buildJson(
      manifestStatuses: manifestStatuses,
      dataResults: dataResults,
      androidPermissions: permissions,
    );
    if (exportPath != null) {
      JsonReporter.writeToFile(exportPath, json);
      stderr.writeln('JSON report written to $exportPath');
    } else {
      print(json);
    }
  } else {
    final reporter = ConsoleReporter(useColor: _supportsAnsi());

    if (runManifests) reporter.printManifests(manifestStatuses);
    if (runDataLabels) reporter.printDataLabels(dataResults);
    if (runAndroid) reporter.printAndroidPermissions(permissions);

    reporter.printFooter();

    if (exportPath != null) {
      final pubspec = _readProjectName(projectDir);
      MarkdownExportReporter.export(
        filePath: exportPath,
        manifestStatuses: manifestStatuses,
        dataResults: dataResults,
        androidPermissions: permissions,
        projectName: pubspec,
      );
      stderr.writeln('\n📄 Markdown report written to $exportPath');
    }
  }

  // ── CI gate ─────────────────────────────────────────────────────────────
  if (failOnMissing) {
    final hasMissing =
        manifestStatuses.any((s) => s.presence == ManifestPresence.missing);
    if (hasMissing) {
      stderr.writeln(
          '\n❌ --fail-on-missing-manifest: one or more native plugins are missing a privacy manifest.');
      exit(1);
    }
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

void _checkProject(String dir) {
  if (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
    _die('No pubspec.yaml found in $dir — is this a Flutter/Dart project?');
  }
}

Never _die(String message) {
  stderr.writeln(message);
  exit(1);
}

String _usage(ArgParser parser) => '''
flutter_privacy_doctor — Flutter privacy compliance auditor

Usage:
  flutter_privacy_doctor [options]                  Full report
  flutter_privacy_doctor manifests [options]        iOS/macOS privacy manifest check only
  flutter_privacy_doctor data-labels [options]      Draft App Store & Play Store labels only
  flutter_privacy_doctor android-permissions [opt]  Android permissions cross-check only

Options:
${parser.usage}
''';

Set<String> _parseIgnore(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  return raw.split(',').map((s) => s.trim()).toSet();
}

List<Map<String, dynamic>> _loadManifestDb() {
  final file = _findAsset('known_privacy_manifest_status.json');
  if (file == null) return [];
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final pkgs = json['packages'] as List<dynamic>? ?? [];
    return pkgs.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

DataCollectionService _loadDataService() {
  final file = _findAsset('known_sdk_data_collection.json');
  if (file == null) return DataCollectionService([]);
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final pkgs = json['packages'] as List<dynamic>? ?? [];
    final entries = pkgs
        .map((e) => DataCollectionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return DataCollectionService(entries);
  } catch (_) {
    return DataCollectionService([]);
  }
}

File? _findAsset(String filename) {
  final scriptDir = p.dirname(Platform.script.toFilePath());
  final candidates = [
    p.join(scriptDir, '..', 'lib', 'src', 'services', filename),
    p.join(scriptDir, 'lib', 'src', 'services', filename),
  ];
  for (final c in candidates) {
    final f = File(p.normalize(c));
    if (f.existsSync()) return f;
  }
  return null;
}

bool _supportsAnsi() {
  if (!stdout.hasTerminal) return false;
  final term = Platform.environment['TERM'] ?? '';
  return term.isNotEmpty && term != 'dumb';
}

String? _readProjectName(String projectDir) {
  final f = File(p.join(projectDir, 'pubspec.yaml'));
  if (!f.existsSync()) return null;
  try {
    final lines = f.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('name:')) {
        return line.split(':').last.trim();
      }
    }
  } catch (_) {}
  return null;
}
