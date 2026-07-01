import 'dart:convert';
import 'dart:io';
import 'package:flutter_privacy_doctor/flutter_privacy_doctor.dart';
import 'package:flutter_privacy_doctor/src/services/data_collection_service.dart';
import 'package:test/test.dart';

void main() {
  // ── AndroidManifestParser ─────────────────────────────────────────────────

  group('AndroidManifestParser', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fpd_android_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('extracts permissions from AndroidManifest.xml', () async {
      final manifestDir = Directory('${tempDir.path}/android/app/src/main')
        ..createSync(recursive: true);
      File('${manifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-permission android:name="android.permission.RECORD_AUDIO" />
</manifest>
''');

      final permissions =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      final names = permissions.map((p) => p.permission).toList();

      expect(names, contains('android.permission.INTERNET'));
      expect(names, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(names, contains('android.permission.CAMERA'));
      expect(names, contains('android.permission.RECORD_AUDIO'));
    });

    test('returns empty list when manifest is missing', () async {
      final result =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      expect(result, isEmpty);
    });

    test('maps ACCESS_FINE_LOCATION to Location / Precise location', () async {
      final manifestDir = Directory('${tempDir.path}/android/app/src/main')
        ..createSync(recursive: true);
      File('${manifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
</manifest>
''');

      final permissions =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      expect(permissions.length, 1);
      expect(permissions.first.playStoreCategory, 'Location');
      expect(permissions.first.playStoreDataType, 'Precise location');
    });

    test('maps CAMERA to Photos and videos', () async {
      final manifestDir = Directory('${tempDir.path}/android/app/src/main')
        ..createSync(recursive: true);
      File('${manifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.CAMERA" /></manifest>
''');
      final permissions =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      expect(permissions.first.playStoreCategory, 'Photos and videos');
    });

    test('maps RECORD_AUDIO to Audio', () async {
      final manifestDir = Directory('${tempDir.path}/android/app/src/main')
        ..createSync(recursive: true);
      File('${manifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.RECORD_AUDIO" /></manifest>
''');
      final permissions =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      expect(permissions.first.playStoreCategory, 'Audio');
    });

    test('returns unmapped entry for unknown permissions', () async {
      final manifestDir = Directory('${tempDir.path}/android/app/src/main')
        ..createSync(recursive: true);
      File('${manifestDir.path}/AndroidManifest.xml').writeAsStringSync('''
<manifest><uses-permission android:name="android.permission.INTERNET" /></manifest>
''');
      final permissions =
          await AndroidManifestParser.getDeclaredPermissions(tempDir.path);
      expect(permissions.first.hasMappedCategory, isFalse);
    });
  });

  // ── DataCollectionService ─────────────────────────────────────────────────

  group('DataCollectionService', () {
    late DataCollectionService service;

    setUp(() {
      final entries = [
        DataCollectionEntry.fromJson({
          'sdkName': 'firebase_analytics',
          'displayName': 'Firebase Analytics',
          'description': 'Analytics',
          'dataCategories': [
            {
              'appStoreCategory': 'Usage Data',
              'appStoreDataType': 'Product Interaction',
              'playStoreCategory': 'App activity',
              'playStoreDataType': 'App interactions',
              'linkedToIdentity': false,
              'usedForTracking': false,
              'purpose': ['analytics'],
            }
          ],
          'requiresPrivacyManifest': true,
          'citationUrl': 'https://firebase.google.com/support/privacy',
        }),
      ];
      service = DataCollectionService(entries);
    });

    test('matches a known plugin by name', () {
      final plugins = [
        const PluginInfo(
            name: 'firebase_analytics', version: '10.7.4', hasIosCode: true),
        const PluginInfo(
            name: 'some_unknown_plugin',
            version: '1.0.0',
            hasAndroidCode: true),
      ];

      final results = service.crossReference(plugins);
      expect(results.length, 2);
      expect(results[0].isInDatabase, isTrue);
      expect(results[0].entry!.sdkName, 'firebase_analytics');
      expect(results[1].isInDatabase, isFalse);
    });

    test('returns databaseSize correctly', () {
      expect(service.databaseSize, 1);
    });
  });

  // ── MarkdownExportReporter ────────────────────────────────────────────────

  group('MarkdownExportReporter', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('fpd_md_test_');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('writes markdown file with all required sections', () {
      final exportPath = '${tempDir.path}/report.md';

      final manifests = [
        const PrivacyManifestStatus(
          pluginName: 'firebase_analytics',
          version: '10.7.4',
          presence: ManifestPresence.present,
          detectionTier: PrivacyManifestTier.knownDatabase,
          suspectedRequiredReasonApi: true,
          pubDevUrl: 'https://pub.dev/packages/firebase_analytics',
          note: 'Firebase iOS SDK includes privacy manifest',
        ),
        const PrivacyManifestStatus(
          pluginName: 'unknown_plugin',
          version: '1.0.0',
          presence: ManifestPresence.unknown,
          detectionTier: PrivacyManifestTier.unknown,
          pubDevUrl: 'https://pub.dev/packages/unknown_plugin',
        ),
      ];

      final entry = DataCollectionEntry.fromJson({
        'sdkName': 'firebase_analytics',
        'displayName': 'Firebase Analytics',
        'description': 'Analytics SDK',
        'dataCategories': [
          {
            'appStoreCategory': 'Usage Data',
            'appStoreDataType': 'Product Interaction',
            'playStoreCategory': 'App activity',
            'playStoreDataType': 'App interactions',
            'linkedToIdentity': false,
            'usedForTracking': false,
            'purpose': ['analytics'],
          }
        ],
        'requiresPrivacyManifest': true,
        'citationUrl': 'https://firebase.google.com/support/privacy',
      });

      final knownPlugin = const PluginInfo(
          name: 'firebase_analytics', version: '10.7.4', hasIosCode: true);
      final unknownPlugin = const PluginInfo(
          name: 'unknown_plugin', version: '1.0.0', hasIosCode: true);

      final dataResults = [
        DataCollectionResult(plugin: knownPlugin, entry: entry),
        DataCollectionResult(plugin: unknownPlugin),
      ];

      final permissions = [
        const PermissionInfo(
          permission: 'android.permission.ACCESS_FINE_LOCATION',
          playStoreCategory: 'Location',
          playStoreDataType: 'Precise location',
        ),
      ];

      MarkdownExportReporter.export(
        filePath: exportPath,
        manifestStatuses: manifests,
        dataResults: dataResults,
        androidPermissions: permissions,
        projectName: 'test_app',
      );

      final content = File(exportPath).readAsStringSync();

      expect(content, contains('# Privacy Compliance Draft Report'));
      expect(content, contains('**Project:** `test_app`'));
      expect(content, contains('Disclaimer'));
      expect(content, contains('iOS / macOS Privacy Manifest Check'));
      expect(content, contains('firebase_analytics'));
      expect(content, contains('✅'));
      expect(content, contains('App Store Privacy Nutrition Label'));
      expect(content, contains('Google Play Data Safety Form'));
      expect(content, contains('Usage Data'));
      expect(content, contains('Not in Database'));
      expect(content, contains('unknown_plugin'));
      expect(content, contains('Android Permissions'));
      expect(content, contains('ACCESS_FINE_LOCATION'));
      expect(content, contains('Location'));
    });
  });

  // ── JsonReporter ──────────────────────────────────────────────────────────

  group('JsonReporter', () {
    test('produces valid JSON with required top-level keys', () {
      final manifests = [
        const PrivacyManifestStatus(
          pluginName: 'test_plugin',
          version: '1.0.0',
          presence: ManifestPresence.present,
          detectionTier: PrivacyManifestTier.localFile,
          pubDevUrl: 'https://pub.dev/packages/test_plugin',
        ),
      ];

      final json = JsonReporter.buildJson(
        manifestStatuses: manifests,
        dataResults: [],
        androidPermissions: [],
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('disclaimer'), isTrue);
      expect(decoded.containsKey('generatedAt'), isTrue);
      expect(decoded.containsKey('privacyManifests'), isTrue);
      expect(decoded.containsKey('dataCollection'), isTrue);
      expect(decoded.containsKey('androidPermissions'), isTrue);

      final pm = (decoded['privacyManifests'] as List).first;
      expect(pm['pluginName'], 'test_plugin');
      expect(pm['presence'], 'present');
    });
  });

  // ── PrivacyManifestStatus model ───────────────────────────────────────────

  group('PrivacyManifestStatus', () {
    test('toJson round-trips correctly', () {
      const status = PrivacyManifestStatus(
        pluginName: 'foo',
        version: '2.0.0',
        presence: ManifestPresence.missing,
        detectionTier: PrivacyManifestTier.knownDatabase,
        suspectedRequiredReasonApi: true,
        note: 'Test note',
        pubDevUrl: 'https://pub.dev/packages/foo',
      );

      final json = status.toJson();
      expect(json['pluginName'], 'foo');
      expect(json['presence'], 'missing');
      expect(json['detectionTier'], 'knownDatabase');
      expect(json['suspectedRequiredReasonApi'], isTrue);
      expect(json['note'], 'Test note');
    });
  });

  // ── PluginInfo ────────────────────────────────────────────────────────────

  group('PluginInfo', () {
    test('isNativePlugin returns true when has iOS or Android code', () {
      const ios = PluginInfo(name: 'a', version: '1.0.0', hasIosCode: true);
      const android =
          PluginInfo(name: 'b', version: '1.0.0', hasAndroidCode: true);
      const pure = PluginInfo(name: 'c', version: '1.0.0');

      expect(ios.isNativePlugin, isTrue);
      expect(android.isNativePlugin, isTrue);
      expect(pure.isNativePlugin, isFalse);
    });
  });
}
