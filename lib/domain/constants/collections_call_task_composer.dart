import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/value_objects/collections_call_task.dart';

/// On-device Appendix C.3 CALL-E task strings.
///
/// Templates match [`docs/roadmap_v3.md`](../../../docs/roadmap_v3.md) Appendix
/// C.3. Amounts are integer minor units. Never invents money. No shame language.
abstract final class CollectionsCallTaskComposer {
  /// English close-day task (byte-for-byte with roadmap C.3).
  static const String taskTemplateEnCloseDay =
      'Call {{customer_name}} on behalf of {{store_name}}. '
      "Identify yourself as the store's assistant, not a government collector. "
      'Their outstanding balance is {{amount_line}}. '
      'Ask whether they can promise a payment date and amount. '
      'Be brief, polite, and stop if they refuse. '
      'Return structured fields only: promised / refused / voicemail / '
      'no_answer / wrong_number / callback_requested, integer minor-unit amount '
      'if they state one, ISO date if they state one.';

  /// English credit-limit extra sentence.
  static const String taskCreditLimitExtraEn =
      'Also tell them new goods are on hold until a payment is arranged. '
      'Record acknowledged_hold if they understand.';

  /// Arabic close-day task (equivalent meaning; schema tokens stay English).
  static const String taskTemplateArCloseDay =
      'اتصل بـ{{customer_name}} نيابةً عن {{store_name}}. '
      'عرّف نفسك كمساعد المتجر وليس كمُحصّل حكومي. '
      'رصيدهم المستحق {{amount_line}}. '
      'اسأل عما إذا كان بإمكانهم الوعد بتاريخ ومبلغ سداد. '
      'كن مختصراً ومهذباً وتوقف إذا رفضوا. '
      'أعد حقولاً منظمة فقط: promised / refused / voicemail / '
      'no_answer / wrong_number / callback_requested، ومبلغاً بأصغر وحدة '
      'نقدية إن ذكروه، وتاريخ ISO إن ذكروه.';

  /// Arabic credit-limit extra sentence.
  static const String taskCreditLimitExtraAr =
      'أخبرهم أيضاً أن البضائع الجديدة معلّقة حتى يتم ترتيب سداد. '
      'سجّل acknowledged_hold إذا فهموا.';

  /// Fills C.3 placeholders.
  static String fillTemplate(
    String template, {
    required String customerName,
    required String storeName,
    required String amountLine,
  }) {
    return template
        .replaceAll('{{customer_name}}', customerName)
        .replaceAll('{{store_name}}', storeName)
        .replaceAll('{{amount_line}}', amountLine);
  }

  /// Filled C.3 task plus named params. Integer money only.
  static CollectionsCallTask compose({
    required String locale,
    required String storeName,
    required String contactName,
    required int amountMinor,
    required String currencyCode,
    CallBatchTrigger trigger = CallBatchTrigger.closeDay,
  }) {
    final english = CollectionsReminderDraftComposer.normalizeLocale(locale) == 'en';
    final store = CollectionsReminderDraftComposer.resolveStoreName(storeName);
    final name = contactName.trim();
    final amountLine = CollectionsReminderDraftComposer.formatAmountLine(
      locale: locale,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
    );

    var template = english ? taskTemplateEnCloseDay : taskTemplateArCloseDay;
    if (trigger == CallBatchTrigger.creditLimit) {
      template += ' ${english ? taskCreditLimitExtraEn : taskCreditLimitExtraAr}';
    }

    final task = fillTemplate(
      template,
      customerName: name,
      storeName: store,
      amountLine: amountLine,
    );

    return CollectionsCallTask(
      task: task,
      customerName: name,
      storeName: store,
      amountLine: amountLine,
    );
  }
}
