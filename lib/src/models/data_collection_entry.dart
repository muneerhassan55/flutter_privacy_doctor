class DataCategory {
  final String appStoreCategory;
  final String appStoreDataType;
  final String playStoreCategory;
  final String playStoreDataType;
  final bool linkedToIdentity;
  final bool usedForTracking;
  final List<String> purpose;

  DataCategory({
    required this.appStoreCategory,
    required this.appStoreDataType,
    required this.playStoreCategory,
    required this.playStoreDataType,
    required this.linkedToIdentity,
    required this.usedForTracking,
    required this.purpose,
  });

  factory DataCategory.fromJson(Map<String, dynamic> json) {
    return DataCategory(
      appStoreCategory: json['appStoreCategory'] as String? ?? 'Unknown',
      appStoreDataType: json['appStoreDataType'] as String? ?? 'Unknown',
      playStoreCategory: json['playStoreCategory'] as String? ?? 'Unknown',
      playStoreDataType: json['playStoreDataType'] as String? ?? 'Unknown',
      linkedToIdentity: json['linkedToIdentity'] as bool? ?? false,
      usedForTracking: json['usedForTracking'] as bool? ?? false,
      purpose:
          (json['purpose'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

class DataCollectionEntry {
  final String sdkName;
  final String description;
  final List<DataCategory> dataCategories;
  final bool requiresPrivacyManifest;
  final String citationUrl;

  DataCollectionEntry({
    required this.sdkName,
    required this.description,
    required this.dataCategories,
    required this.requiresPrivacyManifest,
    required this.citationUrl,
  });

  factory DataCollectionEntry.fromJson(Map<String, dynamic> json) {
    return DataCollectionEntry(
      sdkName: json['sdkName'] as String,
      description: json['description'] as String? ?? '',
      dataCategories: (json['dataCategories'] as List?)
              ?.map((e) => DataCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      requiresPrivacyManifest:
          json['requiresPrivacyManifest'] as bool? ?? false,
      citationUrl: json['citationUrl'] as String? ?? '',
    );
  }
}
