import 'package:daftar/domain/constants/collections_reminder_draft_composer.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const forbidden = [
    'shame',
    'خجل',
    'مماطل',
    'deadbeat',
    'delinquent',
    'تجاهل',
    'إهمال متعمد',
    'harass',
    'ignore',
    'final notice',
    'legal',
    'agency',
    'إنذار',
    'you have not paid',
  ];

  test('C.2 EN Mohamed Ali / Al-Ghanem Store / 500 YER', () {
    final draft = CollectionsReminderDraftComposer.compose(
      locale: 'en',
      storeName: 'Al-Ghanem Store',
      contactName: 'Mohamed Ali',
      amountMinor: 500,
      currencyCode: 'YER',
      tone: ReminderToneBand.reminder,
      ageDays: 12,
    );

    expect(draft.amountLine, '500 YER');
    expect(
      draft.subject,
      'Al-Ghanem Store: outstanding balance 500 YER',
    );
    expect(draft.customerName, 'Mohamed Ali');
    expect(draft.storeName, 'Al-Ghanem Store');
    expect(draft.ctaLine, 'Please arrange payment when you can.');
    expect(
      draft.note,
      'This amount has been outstanding for 12 days.',
    );
    expect(
      draft.body,
      'Hello Mohamed Ali, this is Al-Ghanem Store. '
      'Your outstanding balance is 500 YER. '
      'Please arrange payment when you can. '
      'This amount has been outstanding for 12 days. Thank you.',
    );
    expect(draft.body, isNot(contains('Peace be upon you')));
  });

  test('C.2 AR محمد علي / محل الغانم / 500 ر.ي', () {
    final draft = CollectionsReminderDraftComposer.compose(
      locale: 'ar',
      storeName: 'محل الغانم',
      contactName: 'محمد علي',
      amountMinor: 500,
      currencyCode: 'YER',
      tone: ReminderToneBand.reminder,
      ageDays: 12,
    );

    expect(draft.amountLine, '500 ر.ي');
    expect(draft.subject, 'محل الغانم: رصيد مستحق 500 ر.ي');
    expect(
      draft.body,
      'مرحباً محمد علي، معك محل الغانم. '
      'رصيدك المستحق 500 ر.ي. '
      'نرجو ترتيب السداد عند التمكّن. '
      'مضى على هذا المبلغ 12 يوماً.شكراً لك.',
    );
    expect(draft.body, isNot(contains('السلام عليكم')));
  });

  test('Friendly note is empty; fill matches Cloud Run spacing', () {
    final draft = CollectionsReminderDraftComposer.compose(
      locale: 'en',
      storeName: 'Al-Ghanem Store',
      contactName: 'Mohamed Ali',
      amountMinor: 500,
      currencyCode: 'YER',
      tone: ReminderToneBand.friendly,
      ageDays: 2,
    );
    expect(draft.note, isEmpty);
    expect(
      draft.body,
      'Hello Mohamed Ali, this is Al-Ghanem Store. '
      'Your outstanding balance is 500 YER. '
      'When convenient, we would appreciate a payment.  Thank you.',
    );
  });

  test('firm CTA is distinct from friendly and reminder in AR and EN', () {
    for (final locale in ['ar', 'en']) {
      final friendly = CollectionsReminderDraftComposer.callToAction(
        locale: locale,
        tone: ReminderToneBand.friendly,
      );
      final reminder = CollectionsReminderDraftComposer.callToAction(
        locale: locale,
        tone: ReminderToneBand.reminder,
      );
      final firm = CollectionsReminderDraftComposer.callToAction(
        locale: locale,
        tone: ReminderToneBand.firm,
      );
      expect(firm, isNot(friendly), reason: '$locale firm vs friendly');
      expect(firm, isNot(reminder), reason: '$locale firm vs reminder');
      expect(reminder, isNot(friendly), reason: '$locale reminder vs friendly');
    }
  });

  test('empty store name falls back to Daftar', () {
    final draft = CollectionsReminderDraftComposer.compose(
      locale: 'en',
      storeName: '  ',
      contactName: 'Ali',
      amountMinor: 500,
      currencyCode: 'YER',
      tone: ReminderToneBand.friendly,
    );
    expect(draft.storeName, CollectionsReminderDraftComposer.fallbackStoreName);
    expect(draft.subject, contains(CollectionsReminderDraftComposer.fallbackStoreName));
  });

  test('drafts contain no shame lexicon', () {
    for (final locale in ['ar', 'en']) {
      for (final tone in ReminderToneBand.values) {
        final body = CollectionsReminderDraftComposer.compose(
          locale: locale,
          storeName: 'الغانم',
          contactName: 'محمد',
          amountMinor: 1500,
          currencyCode: 'YER',
          tone: tone,
          ageDays: 40,
        ).body.toLowerCase();
        for (final token in forbidden) {
          expect(
            body.contains(token.toLowerCase()),
            isFalse,
            reason: '$locale $tone must not contain "$token"',
          );
        }
      }
    }
  });
}
