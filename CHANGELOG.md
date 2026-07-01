## 1.0.0

- Initial release.
- iOS/macOS PrivacyInfo.xcprivacy manifest checker (3-tier: local file, known database, unknown).
- Required Reason API heuristic scanner (NSUserDefaults, file timestamps, disk space, boot time, keyboard).
- App Store Privacy Nutrition Label draft generator.
- Google Play Data Safety form draft generator.
- Android permissions cross-checker with Play Store category mapping.
- Bundled database of 25 popular SDKs (Firebase suite, AdMob, Sentry, Google Sign-In, RevenueCat, Braze, etc.).
- CLI subcommands: `manifests`, `data-labels`, `android-permissions`.
- `--json`, `--fail-on-missing-manifest`, `--ignore`, `--export` flags.
- Markdown export reporter for release checklists.
