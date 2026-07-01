# flutter_privacy_doctor

[![pub.dev](https://img.shields.io/pub/v/flutter_privacy_doctor)](https://pub.dev/packages/flutter_privacy_doctor)
[![Dart CI](https://github.com/your-username/flutter_privacy_doctor/actions/workflows/dart.yml/badge.svg)](https://github.com/your-username/flutter_privacy_doctor/actions)

**Audit Flutter dependencies for App Store `PrivacyInfo.xcprivacy` compliance and Google Play Data Safety form generation.**

Every release, manually verifying which iOS SDKs ship a privacy manifest and filling out Apple's Privacy Nutrition Labels and Google Play's Data Safety form is slow, repetitive, and easy to get wrong — leading to App Store rejections or Play Store policy violations.

`flutter_privacy_doctor` automates the heavy lifting:

- **PrivacyInfo.xcprivacy checker** — scans every native iOS/macOS dependency in your project
- **App Store privacy label draft generator** — pre-fills Apple's Privacy Nutrition Label categories
- **Google Play Data Safety form generator** — pre-fills Google's Data Safety categories
- **Android permissions cross-check** — maps `AndroidManifest.xml` permissions to Data Safety disclosures
- **CI/CD gate** — fail the build if manifests are missing before you ship

> ⚠️ **This tool produces a best-effort draft — it is NOT a legal compliance determination.** Always verify final answers against your app's actual behavior and each SDK's current privacy documentation before submitting to the App Store or Play Console.

---

## Why does this tool exist?

Apple requires apps **and the third-party SDKs they bundle** to disclose data collection and ship `PrivacyInfo.xcprivacy` manifests if they use specific "required reason" APIs (NSUserDefaults, file timestamps, disk space, system boot time, active keyboard). The Flutter team has [openly acknowledged](https://github.com/flutter/flutter/issues/131940) there is no built-in system to collect and bundle privacy manifests from arbitrary pub.dev packages — this is a known, unsolved gap.

Developers currently must manually visit each dependency's pub.dev/GitHub page, check for manifest files, and manually fill out both store privacy forms by guessing what each bundled SDK actually collects. **This tool automates that process.**

---

## Installation

```sh
# Global install (recommended — use on any Flutter project)
dart pub global activate flutter_privacy_doctor

# Or as a dev dependency
flutter pub add dev:flutter_privacy_doctor
```

Run `flutter pub get` in your project first so `pubspec.lock` and `.dart_tool/package_config.json` are up to date.

---

## Usage

Run from your Flutter project root:

```sh
# Full report: manifests + draft labels + Android permissions
flutter_privacy_doctor

# Sub-commands (run one check at a time)
flutter_privacy_doctor manifests              # PrivacyInfo.xcprivacy checker only
flutter_privacy_doctor data-labels           # App Store & Play Store draft labels only
flutter_privacy_doctor android-permissions   # Android permissions cross-check only
```

### Options

| Flag | Description |
|------|-------------|
| `--export=<path>.md` | Write full draft report to a Markdown file |
| `--json` | Machine-readable JSON output (for CI pipelines) |
| `--fail-on-missing-manifest` | Exit code 1 if any native plugin lacks a manifest |
| `--ignore=pkg1,pkg2` | Skip specific packages |
| `-p <dir>` / `--project <dir>` | Flutter project root (default: current directory) |

### Export to Markdown

Save the draft answer sheet alongside your release checklist:

```sh
flutter_privacy_doctor --export=docs/privacy_report.md
```

### Pre-release CI gate

Add this to your CI pipeline to block releases when manifests are missing:

```sh
flutter_privacy_doctor manifests --fail-on-missing-manifest
```

### JSON output for CI dashboards

```sh
flutter_privacy_doctor --json > privacy_audit.json
```

---

## How it works

### PrivacyInfo.xcprivacy checker

For each native iOS/macOS plugin, the tool checks in order:

1. **Tier 1 — Local file scan:** inspects the package's source in your pub cache (`~/.pub-cache`) for any `.xcprivacy` file
2. **Tier 2 — Known database:** checks a bundled `known_privacy_manifest_status.json` for popular plugins
3. **Tier 3 — Unknown:** marks the plugin as ❓ with a link to its pub.dev page for manual review

Additionally, a **Required Reason API heuristic** scans native `.swift`, `.m`, and `.h` files for known symbols (`NSUserDefaults`, `NSFileModificationDate`, `systemUptime`, etc.) that require a manifest even if one isn't found.

### App Store Privacy Nutrition Label draft

The tool cross-references your dependencies against `known_sdk_data_collection.json` — a community-maintained database of ~25 popular SDKs (Firebase suite, AdMob, Sentry, Google Sign-In, RevenueCat, and more) mapping them to Apple's exact privacy label categories.

### Google Play Data Safety form draft

The same database maps each SDK to Google Play's Data Safety categories, covering linked identity, tracking usage, and data purposes.

### Android permissions cross-check

Parses `android/app/src/main/AndroidManifest.xml` and maps permissions like `ACCESS_FINE_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `READ_CONTACTS` directly to their corresponding Play Store Data Safety categories.

---

## Sample output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  iOS / macOS Privacy Manifest Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ firebase_analytics @10.7.4  [database]
  ✅ shared_preferences @2.2.3  [local file]
      ⚠️  Heuristic: likely uses Required Reason API — manifest is mandatory
  ❌ flutter_facebook_auth @6.2.1  [database]
      ℹ  No privacy manifest bundled as of 6.2.x
      🔗 https://pub.dev/packages/flutter_facebook_auth
  ❓ my_custom_plugin @1.0.0
      ℹ  Not in database — verify manually.
      🔗 https://pub.dev/packages/my_custom_plugin

  Summary: 2 ✅ present  1 ❌ missing  1 ❓ unknown
```

---

## Known SDK database

The bundled `known_sdk_data_collection.json` currently covers:

| SDK | Privacy Docs |
|-----|-------------|
| Firebase Analytics | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Crashlytics | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Messaging | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Auth | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Cloud Firestore | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Remote Config | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Firebase Storage | [firebase.google.com/support/privacy](https://firebase.google.com/support/privacy) |
| Google Mobile Ads (AdMob) | [support.google.com/admob](https://support.google.com/admob/answer/6128543) |
| Sentry | [sentry.io/privacy](https://sentry.io/privacy/) |
| Google Sign-In | [developers.google.com](https://developers.google.com/identity/sign-in/ios/data-disclosure) |
| Sign in with Apple | [developer.apple.com](https://developer.apple.com/sign-in-with-apple/) |
| Geolocator | [pub.dev/packages/geolocator](https://pub.dev/packages/geolocator) |
| Camera | [pub.dev/packages/camera](https://pub.dev/packages/camera) |
| Image Picker | [pub.dev/packages/image_picker](https://pub.dev/packages/image_picker) |
| Shared Preferences | [Apple required-reason docs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) |
| Path Provider | [Apple required-reason docs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) |
| Device Info Plus | [pub.dev/packages/device_info_plus](https://pub.dev/packages/device_info_plus) |
| Facebook Login | [developers.facebook.com](https://developers.facebook.com/docs/ios/app-tracking-transparency) |
| Stripe | [stripe.com/privacy](https://stripe.com/privacy) |
| Amplitude | [amplitude.com/privacy](https://amplitude.com/privacy) |
| Mixpanel | [mixpanel.com/legal/privacy-policy](https://mixpanel.com/legal/privacy-policy/) |
| Intercom | [intercom.com/legal/privacy](https://www.intercom.com/legal/privacy) |
| RevenueCat | [revenuecat.com/privacy](https://www.revenuecat.com/privacy) |
| OneSignal | [onesignal.com/privacy_policy](https://onesignal.com/privacy_policy) |
| Braze | [braze.com/company/legal/privacy](https://www.braze.com/company/legal/privacy) |

---

## Contributing to the database

The long-term value of this tool is in keeping `known_sdk_data_collection.json` and `known_privacy_manifest_status.json` current. Both files are structured for easy community contributions — see the `_readme` and `_schema` fields at the top of each file.

To add a new SDK:
1. Add an entry following the existing schema
2. Include a `citationUrl` pointing to the SDK's own privacy documentation
3. Open a pull request

---

## Disclaimer

> **This tool generates a DRAFT starting point — it is NOT a legal compliance determination.**
>
> Before submitting to the App Store or Google Play Console you must:
> - Verify answers against your app's **actual runtime behavior**
> - Check each SDK's **current published privacy documentation**
> - Consult a qualified legal or privacy professional if needed
>
> The authors accept no liability for submissions made solely on the basis of this tool's output.

---

## Related tools

- [flutter_spm_doctor](https://pub.dev/packages/flutter_spm_doctor) — Audit your Flutter project for Swift Package Manager (SPM) compatibility issues. If you use `flutter_privacy_doctor`, you'll likely find `flutter_spm_doctor` useful too.

---

## Resources

- [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Apple: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)
- [Google Play: Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Flutter issue #131940](https://github.com/flutter/flutter/issues/131940) — Flutter's own acknowledgment of the privacy manifest gap
