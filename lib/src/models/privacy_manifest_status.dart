enum PrivacyManifestTier { localFile, knownDatabase, unknown }

enum ManifestPresence { present, missing, unknown }

class PrivacyManifestStatus {
  final String pluginName;
  final String version;
  final ManifestPresence presence;
  final PrivacyManifestTier detectionTier;
  final bool suspectedRequiredReasonApi;
  final String? manifestPath;
  final String? note;
  final String pubDevUrl;

  const PrivacyManifestStatus({
    required this.pluginName,
    required this.version,
    required this.presence,
    required this.detectionTier,
    this.suspectedRequiredReasonApi = false,
    this.manifestPath,
    this.note,
    required this.pubDevUrl,
  });

  Map<String, dynamic> toJson() => {
        'pluginName': pluginName,
        'version': version,
        'presence': presence.name,
        'detectionTier': detectionTier.name,
        'suspectedRequiredReasonApi': suspectedRequiredReasonApi,
        'manifestPath': manifestPath,
        'note': note,
        'pubDevUrl': pubDevUrl,
      };
}
