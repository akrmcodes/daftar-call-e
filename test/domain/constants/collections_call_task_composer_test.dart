import 'package:daftar/domain/constants/collections_call_task_composer.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const roadmapEn =
      'Call {{customer_name}} on behalf of {{store_name}}. '
      "Identify yourself as the store's assistant, not a government collector. "
      'Their outstanding balance is {{amount_line}}. '
      'Ask whether they can promise a payment date and amount. '
      'Be brief, polite, and stop if they refuse. '
      'Return structured fields only: promised / refused / voicemail / '
      'no_answer / wrong_number / callback_requested, integer minor-unit amount '
      'if they state one, ISO date if they state one.';

  test('EN close-day matches roadmap C.3 when filled', () {
    final task = CollectionsCallTaskComposer.compose(
      locale: 'en',
      storeName: 'Khazna Shop',
      contactName: 'Amina',
      amountMinor: 1500,
      currencyCode: 'YER',
    );

    final expected = roadmapEn
        .replaceAll('{{customer_name}}', 'Amina')
        .replaceAll('{{store_name}}', 'Khazna Shop')
        .replaceAll('{{amount_line}}', '1500 YER');

    expect(task.task, expected);
    expect(task.amountLine, '1500 YER');
    expect(task.customerName, 'Amina');
    expect(task.storeName, 'Khazna Shop');
  });

  test('credit-limit trigger appends extra sentence', () {
    final task = CollectionsCallTaskComposer.compose(
      locale: 'en',
      storeName: 'Shop',
      contactName: 'Ali',
      amountMinor: 500,
      currencyCode: 'USD',
      trigger: CallBatchTrigger.creditLimit,
    );

    expect(
      task.task,
      contains(CollectionsCallTaskComposer.taskCreditLimitExtraEn),
    );
    expect(task.task, contains('acknowledged_hold'));
  });

  test('AR task contains store name and amount_line', () {
    final task = CollectionsCallTaskComposer.compose(
      locale: 'ar',
      storeName: 'متجر',
      contactName: 'أمينة',
      amountMinor: 1500,
      currencyCode: 'YER',
    );

    expect(task.task, contains('أمينة'));
    expect(task.task, contains('متجر'));
    expect(task.task, contains('1500 ر.ي'));
    expect(task.task, contains('promised'));
    expect(task.task, isNot(contains('government collector')));
  });

  test('no shame lexicon in EN template', () {
    expect(
      CollectionsCallTaskComposer.taskTemplateEnCloseDay.toLowerCase(),
      isNot(contains('shame')),
    );
    expect(
      CollectionsCallTaskComposer.taskTemplateEnCloseDay.toLowerCase(),
      isNot(contains('lawsuit')),
    );
  });
}
