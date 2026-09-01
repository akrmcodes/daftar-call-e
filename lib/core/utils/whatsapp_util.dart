import 'package:url_launcher/url_launcher.dart';

/// Deep links to WhatsApp (`wa.me`) with sanitized phone numbers and optional
/// pre-filled message text.
///
/// Native schemes [nativeBusinessSendUri] / [nativeConsumerSendUri] open the
/// WhatsApp Business or consumer send UI. They do not attach PDF or other file
/// streams; share generated PDFs through the system share sheet instead.
final class WhatsAppUtil {
  WhatsAppUtil._();

  /// `whatsapp-smb://send?phone=…` (WhatsApp Business).
  static Uri nativeBusinessSendUri(String sanitizedPhone) => Uri(
    scheme: 'whatsapp-smb',
    host: 'send',
    queryParameters: <String, String>{'phone': sanitizedPhone},
  );

  /// `whatsapp://send?phone=…` (WhatsApp consumer).
  static Uri nativeConsumerSendUri(String sanitizedPhone) => Uri(
    scheme: 'whatsapp',
    host: 'send',
    queryParameters: <String, String>{'phone': sanitizedPhone},
  );

  /// [canLaunchUrl] wrapped so Android 11+ visibility / resolver edge cases
  /// surface as `false` instead of crashing the export flow.
  static Future<bool> safeCanLaunchUrl(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } on Object {
      return false;
    }
  }

  /// Tries WhatsApp Business, then consumer, using native URL schemes.
  ///
  /// Opens a chat composer only — **not** suitable when the user must send an
  /// attached PDF; use the system share sheet for file payloads.
  static Future<bool> tryLaunchNativeWhatsAppSendInOrder(
    String sanitizedPhone,
  ) async {
    if (sanitizedPhone.isEmpty) {
      return false;
    }

    for (final uri in <Uri>[
      nativeBusinessSendUri(sanitizedPhone),
      nativeConsumerSendUri(sanitizedPhone),
    ]) {
      try {
        final ok = await safeCanLaunchUrl(uri);
        if (ok &&
            await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } on Object {
        continue;
      }
    }
    return false;
  }

  /// Normalizes user-entered phone strings for `wa.me` (digits only, country
  /// code, no separators or international-prefix symbols).
  ///
  /// Steps:
  /// 1. Map Arabic-Indic digits (٠–٩) to ASCII 0–9.
  /// 2. Remove ASCII/Unicode whitespace, hyphens, and parentheses.
  /// 3. Strip any leading `+` characters (international prefix symbol).
  /// 4. Repeatedly strip a leading `00` (common international trunk prefix)
  ///    while more than two digits remain, so accidental doubled prefixes are
  ///    collapsed without stripping a single leading `0` used in national
  ///    formats.
  /// 5. Drop any remaining non-digits (e.g. dots) so the result is numeric
  ///    only.
  static String sanitizePhone(String phone) {
    var cleaned = _mapArabicIndicDigits(phone);
    cleaned = cleaned.replaceAll(RegExp(r'[\s\-()]'), '');
    while (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    while (cleaned.startsWith('00') && cleaned.length > 2) {
      cleaned = cleaned.substring(2);
    }
    return cleaned.replaceAll(RegExp(r'\D'), '');
  }

  static final RegExp _arabicIndicDigit = RegExp('[٠-٩]');

  static String _mapArabicIndicDigits(String input) {
    return input.replaceAllMapped(_arabicIndicDigit, (match) {
      final codeUnit = match.group(0)!.codeUnitAt(0);
      return String.fromCharCode(codeUnit - 0x0660 + 0x30);
    });
  }

  /// Opens WhatsApp for [phone] with an optional [message].
  ///
  /// Returns `true` when [launchUrl] reports success; `false` if the phone
  /// sanitizes to empty, launch fails, or an error is thrown.
  static Future<bool> openWhatsApp({
    required String phone,
    String? message,
  }) async {
    final sanitizedPhone = sanitizePhone(phone);
    if (sanitizedPhone.isEmpty) {
      return false;
    }

    var query = '';
    final text = message;
    if (text != null && text.isNotEmpty) {
      query = '?text=${Uri.encodeComponent(text)}';
    }
    final uri = Uri.parse('https://wa.me/$sanitizedPhone$query');

    try {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}
