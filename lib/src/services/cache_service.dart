import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Simple 24-hour file-based cache stored in the system temp directory.
class CacheService {
  static const _ttlHours = 24;

  final String _cacheDir;

  CacheService()
      : _cacheDir = p.join(
          Directory.systemTemp.path,
          'flutter_privacy_doctor_cache',
        );

  Future<Map<String, dynamic>?> get(String key) async {
    final file = _fileForKey(key);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final ts = json['_ts'] as int?;
      if (ts == null) return null;

      final age =
          DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age.inHours >= _ttlHours) {
        file.deleteSync();
        return null;
      }

      return json['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Map<String, dynamic> data) async {
    final dir = Directory(_cacheDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final file = _fileForKey(key);
    final payload = {
      '_ts': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Future<void> clear() async {
    final dir = Directory(_cacheDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  File _fileForKey(String key) {
    final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File(p.join(_cacheDir, '$safe.json'));
  }
}
