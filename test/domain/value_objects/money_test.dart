import 'package:daftar/domain/value_objects/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    group('Construction and predicates', () {
      test('Money.zero creates a zero amount for the given currency', () {
        const money = Money.zero('YER');

        expect(money.amount, 0);
        expect(money.currencyCode, 'YER');
        expect(money.isZero, isTrue);
        expect(money.isPositive, isFalse);
        expect(money.isNegative, isFalse);
      });

      test('negative debt amounts are represented as negative integers', () {
        const debt = Money(amount: -1500, currencyCode: 'YER');

        expect(debt.isNegative, isTrue);
        expect(debt.isPositive, isFalse);
        expect(debt.isZero, isFalse);
      });

      test('positive payment amounts are represented as positive integers', () {
        const payment = Money(amount: 500, currencyCode: 'SAR');

        expect(payment.isPositive, isTrue);
        expect(payment.isNegative, isFalse);
      });
    });

    group('Arithmetic', () {
      test('adds same-currency amounts preserving currency code', () {
        const left = Money(amount: 1500, currencyCode: 'YER');
        const right = Money(amount: 500, currencyCode: 'YER');

        final result = left + right;

        expect(result, const Money(amount: 2000, currencyCode: 'YER'));
      });

      test('subtracts same-currency amounts and allows negative results', () {
        const debt = Money(amount: 1500, currencyCode: 'YER');
        const payment = Money(amount: 2000, currencyCode: 'YER');

        final result = debt - payment;

        expect(result, const Money(amount: -500, currencyCode: 'YER'));
      });

      test('throws ArgumentError when adding different currencies', () {
        const yer = Money(amount: 1000, currencyCode: 'YER');
        const sar = Money(amount: 1000, currencyCode: 'SAR');

        expect(
          () => yer + sar,
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('YER'),
            ),
          ),
        );
        expect(
          () => yer + sar,
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(contains('SAR'), contains('forbidden')),
            ),
          ),
        );
      });

      test('throws ArgumentError when subtracting different currencies', () {
        const yer = Money(amount: 1000, currencyCode: 'YER');
        const usd = Money(amount: 100, currencyCode: 'USD');

        expect(() => yer - usd, throwsArgumentError);
      });

      test('multiplies amount by integer scalar without changing currency', () {
        const unitPrice = Money(amount: 250, currencyCode: 'YER');

        expect(
          unitPrice * 3,
          const Money(amount: 750, currencyCode: 'YER'),
        );
        expect(
          unitPrice * 0,
          const Money(amount: 0, currencyCode: 'YER'),
        );
        expect(
          unitPrice * -2,
          const Money(amount: -500, currencyCode: 'YER'),
        );
      });

      test('unary negation and abs preserve currency semantics', () {
        const negative = Money(amount: -1500, currencyCode: 'YER');

        expect(-negative, const Money(amount: 1500, currencyCode: 'YER'));
        expect(negative.abs, const Money(amount: 1500, currencyCode: 'YER'));
      });

      test('adding zero is an identity operation', () {
        const amount = Money(amount: 42, currencyCode: 'USD');
        const zero = Money.zero('USD');

        expect(amount + zero, amount);
        expect(zero + amount, amount);
      });
    });

    group('Comparison', () {
      test('compares same-currency amounts with relational operators', () {
        const smaller = Money(amount: 100, currencyCode: 'YER');
        const equal = Money(amount: 100, currencyCode: 'YER');
        const larger = Money(amount: 200, currencyCode: 'YER');

        expect(smaller < larger, isTrue);
        expect(smaller <= equal, isTrue);
        expect(larger > smaller, isTrue);
        expect(larger >= equal, isTrue);
        expect(smaller > larger, isFalse);
      });

      test('throws ArgumentError when comparing different currencies', () {
        const yer = Money(amount: 100, currencyCode: 'YER');
        const sar = Money(amount: 100, currencyCode: 'SAR');

        expect(() => yer > sar, throwsArgumentError);
        expect(() => yer >= sar, throwsArgumentError);
        expect(() => yer < sar, throwsArgumentError);
        expect(() => yer <= sar, throwsArgumentError);
      });

      test('compares negative debt balances correctly', () {
        const deeperDebt = Money(amount: -5000, currencyCode: 'YER');
        const lighterDebt = Money(amount: -1000, currencyCode: 'YER');

        expect(deeperDebt < lighterDebt, isTrue);
        expect(lighterDebt > deeperDebt, isTrue);
      });
    });

    group('Equality', () {
      test('two instances with same amount and currency are equal', () {
        const a = Money(amount: 1500, currencyCode: 'YER');
        const b = Money(amount: 1500, currencyCode: 'YER');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differs when amount or currency code differs', () {
        const base = Money(amount: 1500, currencyCode: 'YER');

        expect(base, isNot(equals(const Money(amount: 1501, currencyCode: 'YER'))));
        expect(base, isNot(equals(const Money(amount: 1500, currencyCode: 'SAR'))));
      });

      test('currency codes are case-sensitive for equality and arithmetic', () {
        const upper = Money(amount: 100, currencyCode: 'YER');
        const lower = Money(amount: 100, currencyCode: 'yer');

        expect(upper, isNot(equals(lower)));
        expect(() => upper + lower, throwsArgumentError);
      });
    });

    group('Display formatting', () {
      test('formats positive amounts with fixed decimal places', () {
        expect(
          const Money(amount: 1500, currencyCode: 'YER').display(2),
          '15.00',
        );
        expect(
          const Money(amount: 50, currencyCode: 'YER').display(2),
          '0.50',
        );
      });

      test('formats negative amounts with sign on the whole part', () {
        expect(
          const Money(amount: -1500, currencyCode: 'YER').display(2),
          '-15.00',
        );
        expect(
          const Money(amount: -1050, currencyCode: 'YER').display(2),
          '-10.50',
        );
      });

      test('returns raw integer string when decimal places are zero or negative', () {
        expect(
          const Money(amount: 1500, currencyCode: 'YER').display(0),
          '1500',
        );
        expect(
          const Money(amount: -99, currencyCode: 'YER').display(-1),
          '-99',
        );
      });

      test('displayForCurrency uses built-in precision rules', () {
        expect(
          const Money(amount: 1500, currencyCode: 'YER').displayForCurrency(),
          '1500',
        );
        expect(
          const Money(amount: 1500, currencyCode: 'SAR').displayForCurrency(),
          '15.00',
        );
      });

      test('handles large integer amounts without precision loss', () {
        const large = Money(amount: 999999999999, currencyCode: 'YER');

        expect(large.display(2), '9999999999.99');
        expect(large.amount, 999999999999);
      });
    });

    group('Edge cases', () {
      test('supports max safe integer amounts for same-currency arithmetic', () {
        const nearMax = Money(amount: 9007199254740991, currencyCode: 'YER');
        const one = Money(amount: 1, currencyCode: 'YER');

        expect(nearMax + one, const Money(amount: 9007199254740992, currencyCode: 'YER'));
      });

      test('toString includes amount and currency code', () {
        expect(
          const Money(amount: 1500, currencyCode: 'YER').toString(),
          'Money(1500 YER)',
        );
      });
    });

    group('Negative and edge cases', () {
      test('displayForCurrency applies per-currency decimal rules', () {
        expect(
          const Money(amount: 123456, currencyCode: 'USD').displayForCurrency(),
          '1234.56',
        );
        expect(
          const Money(amount: 99, currencyCode: 'SAR').displayForCurrency(),
          '0.99',
        );
      });

      test('comparison operators throw on every cross-currency relational op', () {
        const yer = Money(amount: 1, currencyCode: 'YER');
        const usd = Money(amount: 1, currencyCode: 'USD');

        expect(() => yer < usd, throwsArgumentError);
        expect(() => yer <= usd, throwsArgumentError);
        expect(() => yer > usd, throwsArgumentError);
        expect(() => yer >= usd, throwsArgumentError);
      });

      test('multiplication by negative scalar inverts sign', () {
        const base = Money(amount: 100, currencyCode: 'YER');
        expect(base * -3, const Money(amount: -300, currencyCode: 'YER'));
      });

      test('display preserves sign on fractional YER amounts when forced to 2 dp', () {
        expect(
          const Money(amount: -5, currencyCode: 'YER').display(2),
          '-0.05',
        );
      });

      test('zero instances with different currency codes are not equal', () {
        expect(
          const Money.zero('YER'),
          isNot(equals(const Money.zero('SAR'))),
        );
      });
    });
  });
}
