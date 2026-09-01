import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_reminder_draft.dart';
import 'package:daftar/domain/value_objects/money.dart';

/// On-device Appendix C.2 reminder drafts. Amounts are integer minor units.
///
/// Templates match Cloud Run `agent/email_send/c2_body.py` 1:1. Never invents
/// money. No shame language. Arabic default; English when [normalizeLocale]
/// is `en`.
abstract final class CollectionsReminderDraftComposer {
  /// Store name when the merchant profile is empty.
  static const String fallbackStoreName = 'Daftar';

  /// English C.2 body (same placeholders as Cloud Run).
  static const String bodyTemplateEn =
      'Hello {{customer_name}}, this is {{store_name}}. '
      'Your outstanding balance is {{amount_line}}. '
      '{{cta_line}} {{note}} Thank you.';

  /// Arabic C.2 body (same placeholders as Cloud Run).
  static const String bodyTemplateAr =
      'مرحباً {{customer_name}}، معك {{store_name}}. '
      'رصيدك المستحق {{amount_line}}. '
      '{{cta_line}} {{note}}شكراً لك.';

  /// English C.2 subject.
  static const String subjectTemplateEn =
      '{{store_name}}: outstanding balance {{amount_line}}';

  /// Arabic C.2 subject.
  static const String subjectTemplateAr =
      '{{store_name}}: رصيد مستحق {{amount_line}}';

  /// Maps settings locale to `ar` or `en`.
  static String normalizeLocale(String raw) {
    return raw.toLowerCase().startsWith('en') ? 'en' : 'ar';
  }

  /// Resolves a display store name.
  static String resolveStoreName(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? fallbackStoreName : trimmed;
  }

  /// Compact Arabic currency labels for C.2 `amount_line`. Never `double`.
  static String compactCurrencyLabel(String currencyCode, {required bool arabic}) {
    final code = currencyCode.trim().toUpperCase();
    if (!arabic) {
      return code;
    }
    return switch (code) {
      'YER' => 'ر.ي',
      'SAR' => 'ر.س',
      'USD' => r'$',
      'AED' => 'د.إ',
      'KWD' => 'د.ك',
      'EGP' => 'ج.م',
      _ => code,
    };
  }

  /// Integer minor units → C.2 `amount_line` (`500 YER` / `500 ر.ي`).
  static String formatAmountLine({
    required String locale,
    required int amountMinor,
    required String currencyCode,
  }) {
    final formatted = Money(
      amount: amountMinor,
      currencyCode: currencyCode,
    ).displayForCurrency();
    final arabic = normalizeLocale(locale) != 'en';
    final label = compactCurrencyLabel(currencyCode, arabic: arabic);
    return '$formatted $label';
  }

  /// Tone call-to-action (distinct per [ReminderToneBand]).
  static String callToAction({
    required String locale,
    required ReminderToneBand tone,
  }) {
    final english = normalizeLocale(locale) == 'en';
    return switch (tone) {
      ReminderToneBand.friendly => english
          ? 'When convenient, we would appreciate a payment.'
          : 'إن تيسّر السداد نكون شاكرين.',
      ReminderToneBand.reminder => english
          ? 'Please arrange payment when you can.'
          : 'نرجو ترتيب السداد عند التمكّن.',
      ReminderToneBand.firm => english
          ? 'Please settle this outstanding balance at your earliest convenience.'
          : 'نرجو تسوية المبلغ القائم في أقرب وقت يناسبكم.',
    };
  }

  /// Optional age sentence. Friendly drafts omit it (`note` is empty).
  static String? ageRationale({
    required String locale,
    required ReminderToneBand tone,
    required int ageDays,
  }) {
    if (tone == ReminderToneBand.friendly) {
      return null;
    }
    final days = ageDays < 0 ? 0 : ageDays;
    if (normalizeLocale(locale) == 'en') {
      return 'This amount has been outstanding for $days days.';
    }
    return tone == ReminderToneBand.firm
        ? 'ما زال قائماً منذ $days يوماً.'
        : 'مضى على هذا المبلغ $days يوماً.';
  }

  /// Fills C.2 placeholders the same way Cloud Run `assemble_c2_body` does.
  static String fillTemplate(
    String template, {
    required String customerName,
    required String storeName,
    required String amountLine,
    required String ctaLine,
    required String note,
  }) {
    return template
        .replaceAll('{{customer_name}}', customerName)
        .replaceAll('{{store_name}}', storeName)
        .replaceAll('{{amount_line}}', amountLine)
        .replaceAll('{{cta_line}}', ctaLine)
        .replaceAll('{{note}}', note);
  }

  /// Subject + body + named params. Integer money only.
  static CollectionsReminderDraft compose({
    required String locale,
    required String storeName,
    required String contactName,
    required int amountMinor,
    required String currencyCode,
    required ReminderToneBand tone,
    int? ageDays,
  }) {
    final english = normalizeLocale(locale) == 'en';
    final store = resolveStoreName(storeName);
    final name = contactName.trim();
    final amountLine = formatAmountLine(
      locale: locale,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
    );
    final ctaLine = callToAction(locale: locale, tone: tone);
    final note = ageRationale(
          locale: locale,
          tone: tone,
          ageDays: ageDays ?? 0,
        ) ??
        '';
    final subjectTemplate = english ? subjectTemplateEn : subjectTemplateAr;
    final bodyTemplate = english ? bodyTemplateEn : bodyTemplateAr;
    final subject = fillTemplate(
      subjectTemplate,
      customerName: name,
      storeName: store,
      amountLine: amountLine,
      ctaLine: ctaLine,
      note: note,
    );
    final body = fillTemplate(
      bodyTemplate,
      customerName: name,
      storeName: store,
      amountLine: amountLine,
      ctaLine: ctaLine,
      note: note,
    );
    return CollectionsReminderDraft(
      subject: subject,
      body: body,
      customerName: name,
      storeName: store,
      amountLine: amountLine,
      ctaLine: ctaLine,
      note: note,
    );
  }
}
