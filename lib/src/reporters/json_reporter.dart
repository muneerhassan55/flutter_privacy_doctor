import 'dart:convert';
import 'dart:io';
import '../models/privacy_manifest_status.dart';
import '../services/android_manifest_parser.dart';
import '../services/data_collection_service.dart';
import '../disclaimers.dart';

class JsonReporter {
  static String buildJson({
    required List<PrivacyManifestStatus> manifestStatuses,
    required List<DataCollectionResult> dataResults,
    required List<PermissionInfo> androidPermissions,
  }) {
    final output = {
      'disclaimer': Disclaimers.short,
      'generatedAt': DateTime.now().toIso8601String(),
      'tool': 'flutter_privacy_doctor',
      'privacyManifests': manifestStatuses.map((s) => s.toJson()).toList(),
      'dataCollection': {
        'inDatabase': dataResults
            .where((r) => r.isInDatabase)
            .map((r) => {
                  'package': r.plugin.name,
                  'version': r.plugin.version,
                  'sdkName': r.entry!.sdkName,
                  'description': r.entry!.description,
                  'dataCategories': r.entry!.dataCategories
                      .map((c) => {
                            'appStoreCategory': c.appStoreCategory,
                            'appStoreDataType': c.appStoreDataType,
                            'playStoreCategory': c.playStoreCategory,
                            'playStoreDataType': c.playStoreDataType,
                            'linkedToIdentity': c.linkedToIdentity,
                            'usedForTracking': c.usedForTracking,
                            'purpose': c.purpose,
                          })
                      .toList(),
                  'citationUrl': r.entry!.citationUrl,
                })
            .toList(),
        'notInDatabase': dataResults
            .where((r) => !r.isInDatabase && r.plugin.isNativePlugin)
            .map((r) => {
                  'package': r.plugin.name,
                  'version': r.plugin.version,
                  'pubDevUrl': 'https://pub.dev/packages/${r.plugin.name}',
                })
            .toList(),
      },
      'androidPermissions': androidPermissions.map((p) => p.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(output);
  }

  static void writeToFile(String path, String json) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(json);
  }
}
