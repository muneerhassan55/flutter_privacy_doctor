/// Centralized disclaimer text reused in console output, JSON output, and Markdown exports.
/// Never imply legal certainty — this tool produces drafts only.
class Disclaimers {
  static const String short =
      "Draft only — verify against your app's actual behavior and each SDK's "
      "current documentation before submitting to the App Store or Play Console.";

  static const String full = '''
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  IMPORTANT DISCLAIMER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This report is a DRAFT starting point to speed up your privacy
review — it is NOT a legal compliance determination.

Before submitting to the App Store or Play Console you MUST:
  • Verify final answers against your app's actual runtime behavior.
  • Check each SDK's current, published privacy documentation.
  • Consult a qualified legal or privacy professional if in doubt.

Automated heuristics can miss data collection or flag false
positives. The authors of flutter_privacy_doctor accept no
liability for submissions made based solely on this output.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━''';

  static const String markdownBlock = '''
> **⚠️ Disclaimer — Draft Only**
>
> This report is a **best-effort draft** to speed up your privacy review.
> It is **not** a legal compliance determination or guarantee.
> Before submitting to the App Store or Google Play Console you must:
> - Verify answers against your app's **actual runtime behavior**.
> - Check each SDK's **current published privacy documentation**.
> - Consult a qualified legal or privacy professional if needed.
>
> The authors of `flutter_privacy_doctor` accept no liability for
> submissions made solely on the basis of this output.
''';
}
