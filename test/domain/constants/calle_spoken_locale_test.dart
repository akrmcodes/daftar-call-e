import 'package:daftar/domain/constants/calle_spoken_locale.dart';
import 'package:daftar/domain/constants/collections_call_task_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('US + Arabic UI is en-US with English C.3', () {
    expect(
      CalleSpokenLocale.bcp47(region: 'US', uiLocale: 'ar'),
      'en-US',
    );
    expect(
      CalleSpokenLocale.taskLanguage(region: 'us', uiLocale: 'ar-SA'),
      'en',
    );
    final task = CollectionsCallTaskComposer.compose(
      locale: CalleSpokenLocale.taskLanguage(region: 'US', uiLocale: 'ar'),
      storeName: 'Khazna Shop',
      contactName: 'Mohamed',
      amountMinor: 50000,
      currencyCode: 'USD',
    );
    expect(task.task, contains('Call Mohamed on behalf of'));
    expect(task.task, isNot(contains('اتصل')));
  });

  test('AE + Arabic UI is ar-AE with Arabic C.3', () {
    expect(
      CalleSpokenLocale.bcp47(region: 'AE', uiLocale: 'ar'),
      'ar-AE',
    );
    expect(
      CalleSpokenLocale.taskLanguage(region: 'AE', uiLocale: 'ar'),
      'ar',
    );
    final task = CollectionsCallTaskComposer.compose(
      locale: CalleSpokenLocale.taskLanguage(region: 'AE', uiLocale: 'ar'),
      storeName: 'متجر',
      contactName: 'أمينة',
      amountMinor: 1500,
      currencyCode: 'YER',
    );
    expect(task.task, contains('اتصل بـأمينة'));
    expect(task.task, contains('promised'));
  });

  test('SA + English UI is en-US', () {
    expect(
      CalleSpokenLocale.bcp47(region: 'SA', uiLocale: 'en'),
      'en-US',
    );
    expect(
      CalleSpokenLocale.taskLanguage(region: 'SA', uiLocale: 'en-US'),
      'en',
    );
  });

  test('EG and OM Arabic UI use regional BCP-47', () {
    expect(
      CalleSpokenLocale.bcp47(region: 'EG', uiLocale: 'ar'),
      'ar-EG',
    );
    expect(
      CalleSpokenLocale.bcp47(region: 'OM', uiLocale: 'ar'),
      'ar-OM',
    );
  });
}
