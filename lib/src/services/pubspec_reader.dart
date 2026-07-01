import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../models/plugin_info.dart';

class PubspecReader {
  /// Reads resolved dependencies from pubspec.lock + .dart_tool/package_config.json.
  /// Falls back to pub-cache path resolution when package_config.json is absent.
  static Future<List<PluginInfo>> getResolvedPlugins(String projectDir) async {
    final pubspecLockPath = p.join(projectDir, 'pubspec.lock');
    if (!File(pubspecLockPath).existsSync()) {
      throw Exception(
          'pubspec.lock not found. Please run `flutter pub get` first.');
    }

    final pubspecLockContent = await File(pubspecLockPath).readAsString();
    final lockYaml = loadYaml(pubspecLockContent) as YamlMap;
    final packages = lockYaml['packages'] as YamlMap?;
    if (packages == null) return [];

    // Build version map from lock file
    final Map<String, String> versions = {};
    for (final key in packages.keys) {
      final pkg = packages[key] as YamlMap;
      versions[key.toString()] = pkg['version']?.toString() ?? 'unknown';
    }

    // Try package_config.json for exact resolved paths
    final packageConfigPath =
        p.join(projectDir, '.dart_tool', 'package_config.json');
    Map<String, String>? configPaths;
    if (File(packageConfigPath).existsSync()) {
      configPaths = _parsePackageConfig(packageConfigPath, projectDir);
    }

    final List<PluginInfo> plugins = [];
    final projectName = _readProjectName(projectDir);

    for (final key in packages.keys) {
      final name = key.toString();
      if (name == projectName) continue;

      final pkg = packages[name] as YamlMap;
      final version = pkg['version']?.toString() ?? 'unknown';
      final source = pkg['source']?.toString() ?? '';

      String? resolvedPath = configPaths?[name];
      if (resolvedPath == null) {
        if (source == 'hosted') {
          resolvedPath = _pubCachePath(name, version);
        } else if (source == 'path') {
          final desc = pkg['description'];
          if (desc is YamlMap) {
            final rel = desc['path']?.toString();
            if (rel != null) {
              resolvedPath = p.isAbsolute(rel)
                  ? rel
                  : p.normalize(p.join(projectDir, rel));
            }
          }
        }
      }

      final hasIos = _hasSubdir(resolvedPath, 'ios');
      final hasAndroid = _hasSubdir(resolvedPath, 'android');
      final hasMacos = _hasSubdir(resolvedPath, 'macos');

      plugins.add(PluginInfo(
        name: name,
        version: version,
        path: resolvedPath,
        hasIosCode: hasIos,
        hasAndroidCode: hasAndroid,
        isMacosPlugin: hasMacos,
      ));
    }

    return plugins;
  }

  static Map<String, String> _parsePackageConfig(
      String configPath, String projectDir) {
    final result = <String, String>{};
    try {
      final content = File(configPath).readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final pkgs = json['packages'] as List<dynamic>? ?? [];
      for (final pkg in pkgs) {
        final name = pkg['name'] as String;
        var rootUri = pkg['rootUri'] as String;
        if (rootUri.startsWith('file://')) {
          rootUri = Uri.parse(rootUri).toFilePath();
        } else if (!p.isAbsolute(rootUri)) {
          rootUri = p.normalize(p.join(p.dirname(configPath), rootUri));
        }
        result[name] = rootUri;
      }
    } catch (_) {}
    return result;
  }

  static bool _hasSubdir(String? base, String sub) {
    if (base == null) return false;
    return Directory(p.join(base, sub)).existsSync();
  }

  static String _pubCachePath(String name, String version) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return p.join(home, '.pub-cache', 'hosted', 'pub.dev', '$name-$version');
  }

  static String? _readProjectName(String projectDir) {
    final f = File(p.join(projectDir, 'pubspec.yaml'));
    if (!f.existsSync()) return null;
    try {
      final yaml = loadYaml(f.readAsStringSync()) as YamlMap;
      return yaml['name']?.toString();
    } catch (_) {
      return null;
    }
  }
}
