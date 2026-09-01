import 'package:share_plus/share_plus.dart';

/// Cross-platform sharing for generated account statement PDFs.
///
/// WhatsApp Business (`whatsapp-smb://`) and consumer (`whatsapp://`) URL
/// schemes can open a chat composer with a phone query, but they cannot attach
/// arbitrary binary documents such as PDFs on iOS or Android. Targeting a
/// specific package with an `Intent.EXTRA_STREAM` requires Android-only code
/// beyond what `share_plus` exposes, so PDF export does **not** use those URL
/// schemes (attempts 1–2 would open an empty chat without the file).
///
/// **Fallback chain for PDF export:** Attempts 1–2 are skipped for binary PDF
/// payloads; **attempt 3** is the system share sheet via `SharePlus`, where the
/// user can choose WhatsApp Business, WhatsApp, or any other handler for
/// `application/pdf`. iOS `LSApplicationQueriesSchemes` and Android manifest
/// `<queries>` still declare `whatsapp` / `whatsapp-smb` so `canLaunchUrl` and
/// other chat deep links work under package visibility rules.
final class StatementShare {
  StatementShare._();

  /// Shares a statement PDF using the OS share sheet (WhatsApp / other targets).
  static Future<ShareResult> shareStatementPdf({
    required XFile file,
    required String shareTitle,
    required String shareSubject,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [file],
        title: shareTitle,
        subject: shareSubject,
      ),
    );
  }
}
