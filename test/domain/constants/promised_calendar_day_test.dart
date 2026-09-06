import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromisedCalendarDay', () {
    test('accepts valid YYYY-MM-DD', () {
      expect(PromisedCalendarDay.tryParse('2026-09-10'), '2026-09-10');
      expect(PromisedCalendarDay.isInvalidPresent('2026-09-10'), isFalse);
    });

    test('rejects invalid calendar day and free text', () {
      expect(PromisedCalendarDay.tryParse('2026-02-30'), isNull);
      expect(PromisedCalendarDay.isInvalidPresent('2026-02-30'), isTrue);
      expect(PromisedCalendarDay.tryParse('next Friday'), isNull);
      expect(PromisedCalendarDay.isInvalidPresent('2026-09-10T00:00:00Z'), isTrue);
    });

    test('null and empty are absence not invalid', () {
      expect(PromisedCalendarDay.tryParse(null), isNull);
      expect(PromisedCalendarDay.isInvalidPresent(null), isFalse);
      expect(PromisedCalendarDay.isInvalidPresent(''), isFalse);
    });
  });
}
