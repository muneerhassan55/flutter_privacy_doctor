# flutter_privacy_doctor — Example

Run from the root of any Flutter project:

```sh
# Activate globally
dart pub global activate flutter_privacy_doctor

# cd into your Flutter app
cd /path/to/your/flutter_app

# Run full report
flutter_privacy_doctor

# iOS manifest check only
flutter_privacy_doctor manifests

# Export Markdown report
flutter_privacy_doctor --export=privacy_report.md

# CI gate — fail if manifests missing
flutter_privacy_doctor manifests --fail-on-missing-manifest
```
