import 'dart:io';
import 'package:path/path.dart' as p;

class PermissionInfo {
  final String permission;
  final String? playStoreCategory;
  final String? playStoreDataType;
  final String? note;

  const PermissionInfo({
    required this.permission,
    this.playStoreCategory,
    this.playStoreDataType,
    this.note,
  });

  bool get hasMappedCategory => playStoreCategory != null;

  Map<String, dynamic> toJson() => {
        'permission': permission,
        'playStoreCategory': playStoreCategory,
        'playStoreDataType': playStoreDataType,
        'note': note,
      };
}

class AndroidManifestParser {
  static const _defaultManifestSubpath =
      'android/app/src/main/AndroidManifest.xml';

  /// Returns declared permissions from AndroidManifest.xml.
  /// Returns an empty list (never throws) if the file is missing or unreadable.
  static Future<List<PermissionInfo>> getDeclaredPermissions(
      String projectDir) async {
    final manifestPath = p.join(projectDir, _defaultManifestSubpath);
    final file = File(manifestPath);
    if (!file.existsSync()) return [];

    String content;
    try {
      content = await file.readAsString();
    } catch (_) {
      return [];
    }

    final permissions = <PermissionInfo>[];
    final regex = RegExp(r'<uses-permission\s+[^>]*android:name="([^"]+)"');
    for (final match in regex.allMatches(content)) {
      final name = match.group(1);
      if (name != null) {
        permissions.add(_buildPermissionInfo(name));
      }
    }
    return permissions;
  }

  static PermissionInfo _buildPermissionInfo(String permission) {
    final p = permission.toUpperCase();

    if (p.contains('ACCESS_FINE_LOCATION')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Location',
        playStoreDataType: 'Precise location',
        note: 'Precise GPS — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('ACCESS_COARSE_LOCATION') ||
        p.contains('ACCESS_BACKGROUND_LOCATION')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Location',
        playStoreDataType: 'Approximate location',
        note: 'Approximate location — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('CAMERA')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Photos and videos',
        playStoreDataType: 'Photos (Camera)',
        note: 'Camera access — declare photos/videos in Data Safety form.',
      );
    }
    if (p.contains('READ_CONTACTS') || p.contains('WRITE_CONTACTS')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Contacts',
        playStoreDataType: 'Contacts',
        note: 'Contact data — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('RECORD_AUDIO')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Audio',
        playStoreDataType: 'Voice or sound recordings',
        note: 'Microphone access — declare audio in Data Safety form.',
      );
    }
    if (p.contains('READ_CALENDAR') || p.contains('WRITE_CALENDAR')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Calendar',
        playStoreDataType: 'Calendar events',
        note: 'Calendar access — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('BODY_SENSORS') || p.contains('ACTIVITY_RECOGNITION')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Health and fitness',
        playStoreDataType: 'Health info',
        note: 'Health/fitness data — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('READ_CALL_LOG') || p.contains('WRITE_CALL_LOG')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Call logs',
        playStoreDataType: 'Phone or text call log',
        note: 'Call log access — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('READ_PHONE_STATE') ||
        p.contains('READ_PHONE_NUMBERS') ||
        p.contains('CALL_PHONE')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Device or other identifiers',
        playStoreDataType: 'Phone number',
        note: 'Phone identifiers — consider declaring in Data Safety form.',
      );
    }
    if (p.contains('SEND_SMS') || p.contains('READ_SMS')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Messages',
        playStoreDataType: 'SMS or MMS',
        note: 'SMS access — declare in Play Store Data Safety form.',
      );
    }
    if (p.contains('BLUETOOTH') || p.contains('BLUETOOTH_SCAN')) {
      return PermissionInfo(
        permission: permission,
        playStoreCategory: 'Device or other identifiers',
        playStoreDataType: 'Device or other identifiers',
        note: 'Bluetooth — nearby device identifiers may be collected.',
      );
    }

    return PermissionInfo(
      permission: permission,
      note: 'No direct Play Store Data Safety mapping — review manually.',
    );
  }
}
