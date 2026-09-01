import 'package:daftar/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    group('validateName', () {
      test('rejects null empty and whitespace-only names', () {
        expect(Validators.validateName(null), isNotNull);
        expect(Validators.validateName(''), isNotNull);
        expect(Validators.validateName('   '), isNotNull);
      });

      test('accepts Arabic names within length limit', () {
        expect(Validators.validateName('محمد أحمد'), isNull);
      });

      group('Negative and edge cases', () {
        test('rejects names exceeding maxNameLength after trim', () {
          final longName = 'أ' * (Validators.maxNameLength + 1);
          expect(Validators.validateName(longName), isNotNull);
        });

        test('accepts name exactly at maxNameLength', () {
          final exact = 'ب' * Validators.maxNameLength;
          expect(Validators.validateName(exact), isNull);
        });
      });
    });

    group('validateAmount', () {
      test('rejects null empty and non-numeric input', () {
        expect(Validators.validateAmount(null), isNotNull);
        expect(Validators.validateAmount(''), isNotNull);
        expect(Validators.validateAmount('abc'), isNotNull);
      });

      test('accepts valid YER whole amounts', () {
        expect(Validators.validateAmount('1500'), isNull);
        expect(Validators.validateAmount('15,500'), isNull);
      });

      test('accepts valid SAR fractional amounts', () {
        expect(Validators.validateAmount('15.50', currencyCode: 'SAR'), isNull);
      });

      group('Negative and edge cases', () {
        test('rejects zero and negative parsed amounts', () {
          expect(Validators.validateAmount('0'), isNotNull);
          expect(Validators.validateAmount('-100'), isNotNull);
        });

        test('rejects decimal separator for zero-decimal YER', () {
          expect(Validators.validateAmount('10.5'), isNotNull);
        });

        test('rejects excess fractional digits for USD', () {
          expect(Validators.validateAmount('1.234', currencyCode: 'USD'), isNotNull);
        });
      });
    });

    group('validatePhone', () {
      test('accepts null and empty as optional', () {
        expect(Validators.validatePhone(null), isNull);
        expect(Validators.validatePhone(''), isNull);
        expect(Validators.validatePhone('   '), isNull);
      });

      test('accepts formatted international numbers', () {
        expect(Validators.validatePhone('+967 77 123 4567'), isNull);
      });

      group('Negative and edge cases', () {
        test('rejects too few digits after stripping format chars', () {
          expect(Validators.validatePhone('12345'), isNotNull);
        });

        test('rejects letters and symbols in digit body', () {
          expect(Validators.validatePhone('077abc4567'), isNotNull);
          expect(Validators.validatePhone('call-me'), isNotNull);
        });
      });
    });

    group('validateCurrencyCode', () {
      test('accepts valid ISO codes', () {
        expect(Validators.validateCurrencyCode('YER'), isNull);
        expect(Validators.validateCurrencyCode('USD'), isNull);
      });

      group('Negative and edge cases', () {
        test('rejects null empty lowercase and wrong lengths', () {
          expect(Validators.validateCurrencyCode(null), isNotNull);
          expect(Validators.validateCurrencyCode(''), isNotNull);
          expect(Validators.validateCurrencyCode('yer'), isNotNull);
          expect(Validators.validateCurrencyCode('US'), isNotNull);
          expect(Validators.validateCurrencyCode('USDD'), isNotNull);
          expect(Validators.validateCurrencyCode('Y3R'), isNotNull);
        });
      });
    });

    group('validateNotes', () {
      test('accepts null and empty as optional', () {
        expect(Validators.validateNotes(null), isNull);
        expect(Validators.validateNotes(''), isNull);
      });

      group('Negative and edge cases', () {
        test('rejects notes exceeding maxNotesLength', () {
          final long = 'ن' * (Validators.maxNotesLength + 1);
          expect(Validators.validateNotes(long), isNotNull);
        });

        test('accepts notes exactly at maxNotesLength', () {
          final exact = 'م' * Validators.maxNotesLength;
          expect(Validators.validateNotes(exact), isNull);
        });
      });
    });
  });
}
