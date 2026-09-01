import 'package:daftar/core/utils/date_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateUtil', () {
    final anchor = DateTime(2026, 6, 17, 14, 30);

    group('relativeDate', () {
      test('returns اليوم for same calendar day regardless of time', () {
        final morning = DateTime(2026, 6, 17, 6);
        final evening = DateTime(2026, 6, 17, 23, 59);

        expect(DateUtil.relativeDate(morning, now: anchor), 'اليوم');
        expect(DateUtil.relativeDate(evening, now: anchor), 'اليوم');
      });

      test('returns أمس for exactly one day prior', () {
        final yesterday = DateTime(2026, 6, 16, 20);

        expect(DateUtil.relativeDate(yesterday, now: anchor), 'أمس');
      });

      test('returns قبل N أيام for 2 through 6 days ago', () {
        expect(
          DateUtil.relativeDate(DateTime(2026, 6, 15), now: anchor),
          'قبل 2 أيام',
        );
        expect(
          DateUtil.relativeDate(DateTime(2026, 6, 11), now: anchor),
          'قبل 6 أيام',
        );
      });

      test('returns قبل أسبوع for exactly seven days ago', () {
        final weekAgo = DateTime(2026, 6, 10);

        expect(DateUtil.relativeDate(weekAgo, now: anchor), 'قبل أسبوع');
      });

      test('falls back to formatted date for eight or more days ago', () {
        final older = DateTime(2026, 6);

        expect(DateUtil.relativeDate(older, now: anchor), '01/06/2026');
      });

      group('Negative and edge cases', () {
        test('future dates format as absolute date not relative phrase', () {
          final tomorrow = DateTime(2026, 6, 18);

          expect(DateUtil.relativeDate(tomorrow, now: anchor), '18/06/2026');
        });

        test('month boundary within relative window uses قبل N أيام', () {
          final threeDaysAgo = DateTime(2026, 6, 14);

          expect(
            DateUtil.relativeDate(threeDaysAgo, now: anchor),
            'قبل 3 أيام',
          );
        });

        test('leap day formats without throwing', () {
          final leap = DateTime(2024, 2, 29);

          expect(DateUtil.formatDate(leap), '29/02/2024');
        });
      });
    });

    group('formatDate and formatDateLong', () {
      test('pads single-digit day and month with zero', () {
        expect(DateUtil.formatDate(DateTime(2026, 1, 5)), '05/01/2026');
      });

      test('formatDateLong uses Arabic month names with western digits', () {
        expect(
          DateUtil.formatDateLong(DateTime(2026, 3, 15)),
          '15 مارس 2026',
        );
      });
    });

    group('formatTime and arabicDayName', () {
      test('pads hours and minutes', () {
        expect(DateUtil.formatTime(DateTime(2026, 6, 17, 9, 5)), '09:05');
      });

      test('arabicDayName maps weekday index to Arabic label', () {
        expect(
          DateUtil.arabicDayName(DateTime(2026, 6, 17)),
          'الأربعاء',
        );
        expect(
          DateUtil.arabicDayName(DateTime(2026, 6, 19)),
          'الجمعة',
        );
      });

      group('Negative and edge cases', () {
        test('midnight formats as 00:00', () {
          expect(
            DateUtil.formatTime(DateTime(2026, 6, 17)),
            '00:00',
          );
        });

        test('formatTimeArabic mirrors formatTime', () {
          final at = DateTime(2026, 6, 17, 23, 59);
          expect(DateUtil.formatTimeArabic(at), DateUtil.formatTime(at));
        });
      });
    });
  });
}
