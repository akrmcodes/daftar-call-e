import 'package:daftar/application/agent/correct_spoken_amount_minor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseSpokenMajor', () {
    const cases = <(String, int?)>[
      ('Mohammed paid two hundred Riyals', 200),
      ('Mohammed paid 2 hundred Riyals', 200),
      ('two hundreds', 200),
      ('two thousand', 2000),
      ('Mohamed owes one thousand Riyals', 1000),
      ('2k', 2000),
      ('سدد مائتين ريال', 200),
      ('سدد مئتين ريال', 200),
      ('سدد ميتين ريال', 200),
      ('خمسمئة', 500),
      ('خمس مئة', 500),
      ('مية', 100),
      ('مائة وخمسين', 150),
      ('خمسين', 50),
      ('على محمد ألف ريال', 1000),
      ('عليه ٢٠٠ ريال', 200),
      ('عليه ١٬٠٠٠ ريال', 1000),
      ('500 riyals on 14', 500),
      ('Mohamed owes 10000', 10000),
      ('٢ مئة', 200),
    ];

    for (final (goal, spoken) in cases) {
      test('$goal → $spoken', () {
        expect(parseSpokenMajor(goal), spoken);
      });
    }
  });

  group('correctSpokenAmountMinor', () {
    const cases = <(String, String, int, int)>[
      ('Mohammed paid two hundred Riyals', 'YER', 20000, 200),
      ('Mohammed paid 2 hundred Riyals', 'YER', 20000, 200),
      ('two hundreds', 'YER', 20000, 200),
      ('two thousand', 'YER', 20000, 2000),
      ('Mohamed owes one thousand Riyals', 'YER', 10000, 1000),
      ('على محمد ألف ريال', 'YER', 10000, 1000),
      ('سدد مائتين ريال', 'YER', 20000, 200),
      ('سدد مئتين ريال', 'YER', 20000, 200),
      ('سدد ميتين ريال', 'YER', 20000, 200),
      ('خمسمئة', 'YER', 50000, 500),
      ('خمس مئة', 'YER', 50000, 500),
      ('مية', 'YER', 10000, 100),
      ('مائة وخمسين', 'YER', 15000, 150),
      ('خمسين', 'YER', 5000, 50),
      ('عليه ٢٠٠ ريال', 'YER', 20000, 200),
      ('500 riyals on 14', 'YER', 50000, 500),
      ('Mohamed owes 10000', 'YER', 10000, 10000),
      ('Mohamed owes 500', 'YER', 50000, 500),
      ('Mohamed owes 500', 'YER', 500, 500),
      ('Mohamed paid 500', 'USD', 500, 50000),
      ('Mohamed paid 500', 'USD', 50000, 50000),
      ('Mohamed owes 500 sugar', 'USD', 500, 50000),
      ('Ahmed owes 200', 'USD', 200, 20000),
      ('محمد سدد 500', 'USD', 500, 50000),
      ('أحمد عليه 200', 'USD', 200, 20000),
      ('one thousand Riyals', 'YER', 7, 7),
      ('two hundred', 'SAR', 20000, 20000),
      ('one thousand Riyals', 'SAR', 1000000, 100000),
    ];

    for (final (goal, currency, amount, expected) in cases) {
      test('$goal $currency $amount → $expected', () {
        expect(
          correctSpokenAmountMinor(
            goalText: goal,
            currencyCode: currency,
            amountMinor: amount,
          ),
          expected,
        );
      });
    }
  });

  group('correctSpokenAmountMinor hint-scoped compound', () {
    test('English two amounts + two hints snap independently', () {
      const goal = 'Ahmed 500 and Mohamed 300';
      const siblings = ['Ahmed', 'Mohamed'];
      expect(
        correctSpokenAmountMinor(
          goalText: goal,
          currencyCode: 'YER',
          amountMinor: 50000,
          contactHint: 'Ahmed',
          siblingHints: siblings,
        ),
        500,
      );
      expect(
        correctSpokenAmountMinor(
          goalText: goal,
          currencyCode: 'YER',
          amountMinor: 30000,
          contactHint: 'Mohamed',
          siblingHints: siblings,
        ),
        300,
      );
    });

    test('Arabic two amounts + two hints snap independently', () {
      const goal = 'أحمد 500 ومحمد 300';
      const siblings = ['أحمد', 'محمد'];
      expect(
        correctSpokenAmountMinor(
          goalText: goal,
          currencyCode: 'YER',
          amountMinor: 50000,
          contactHint: 'أحمد',
          siblingHints: siblings,
        ),
        500,
      );
      expect(
        correctSpokenAmountMinor(
          goalText: goal,
          currencyCode: 'YER',
          amountMinor: 30000,
          contactHint: 'محمد',
          siblingHints: siblings,
        ),
        300,
      );
    });

    test('single Mohamed owes 500 still snaps 50000→500', () {
      expect(
        correctSpokenAmountMinor(
          goalText: 'Mohamed owes 500',
          currencyCode: 'YER',
          amountMinor: 50000,
          contactHint: 'Mohamed',
        ),
        500,
      );
    });
  });
}
