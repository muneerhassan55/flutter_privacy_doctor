class PluginInfo {
  final String name;
  final String version;
  final String? path;
  final bool hasIosCode;
  final bool hasAndroidCode;
  final bool isMacosPlugin;

  const PluginInfo({
    required this.name,
    required this.version,
    this.path,
    this.hasIosCode = false,
    this.hasAndroidCode = false,
    this.isMacosPlugin = false,
  });

  bool get isNativePlugin => hasIosCode || hasAndroidCode || isMacosPlugin;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'path': path,
        'hasIosCode': hasIosCode,
        'hasAndroidCode': hasAndroidCode,
        'isMacosPlugin': isMacosPlugin,
      };

  @override
  String toString() => 'PluginInfo($name@$version)';
}
