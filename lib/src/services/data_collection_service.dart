import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/data_collection_entry.dart';
import '../models/plugin_info.dart';

class DataCollectionResult {
  final PluginInfo plugin;
  final DataCollectionEntry? entry;

  const DataCollectionResult({required this.plugin, this.entry});

  bool get isInDatabase => entry != null;
}

class DataCollectionService {
  final List<DataCollectionEntry> _db;

  DataCollectionService(this._db);

  /// Loads the bundled known_sdk_data_collection.json.
  static DataCollectionService loadBundled() {
    final scriptDir = p.dirname(Platform.script.toFilePath());
    // Try several candidate paths (dev layout vs. pub global layout)
    final candidates = [
      p.join(scriptDir, '..', 'lib', 'src', 'services',
          'known_sdk_data_collection.json'),
      p.join(scriptDir, 'lib', 'src', 'services',
          'known_sdk_data_collection.json'),
    ];

    for (final candidate in candidates) {
      final file = File(p.normalize(candidate));
      if (file.existsSync()) {
        return _parseFile(file);
      }
    }
    // Fallback: empty DB, tool will still work with "not in database" notices
    return DataCollectionService([]);
  }

  static DataCollectionService _parseFile(File file) {
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

  /// Cross-references the given plugins against the database.
  List<DataCollectionResult> crossReference(List<PluginInfo> plugins) {
    return plugins.map((plugin) {
      final entry = _db.cast<DataCollectionEntry?>().firstWhere(
            (e) => e!.sdkName == plugin.name,
            orElse: () => null,
          );
      return DataCollectionResult(plugin: plugin, entry: entry);
    }).toList();
  }

  int get databaseSize => _db.length;
}
