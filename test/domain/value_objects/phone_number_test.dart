import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumber', () {
    group('Normalization — Yemeni formats', () {
      const yemeniOperatorPrefixes = ['71', '73', '77', '78'];

      for (final prefix in yemeniOperatorPrefixes) {
        test('normalizes local 9-digit number starting with $prefix', () {
          final local = '${prefix}1234567';
          final phone = PhoneNumber(local);

          expect(phone.normalized, '967$local');
        });

        test('normalizes local 10-digit number with leading 0 and prefix $prefix', () {
          final local = '0${prefix}1234567';
          final phone = PhoneNumber(local);

          expect(phone.normalized, '967${prefix}1234567');
        });

        test('normalizes +967 international format with prefix $prefix', () {
          final formatted = '+967 $prefix 123 4567';
          final phone = PhoneNumber(formatted);

          expect(phone.normalized, '967${prefix}1234567');
        });

        test('normalizes 00967 international format with prefix $prefix', () {
          final formatted = '00967${prefix}1234567';
          final phone = PhoneNumber(formatted);

          expect(phone.normalized, '967${prefix}1234567');
        });
      }

      test('normalizes already-normalized Yemen digits without mutation', () {
        const phone = PhoneNumber('967771234567');

        expect(phone.normalized, '967771234567');
      });

      test('strips spaces, dashes, parentheses, and dots from Yemen input', () {
        const phone = PhoneNumber('+967 (77) 123-456.7');

        expect(phone.normalized, '967771234567');
      });

      test('collapses repeated 00 international trunk prefixes', () {
        const phone = PhoneNumber('0096700967771234567');

        expect(phone.normalized, '967771234567');
      });
    });

    group('Normalization — Saudi formats', () {
      test('normalizes local 10-digit Saudi number with leading 05', () {
        const phone = PhoneNumber('0501234567');

        expect(phone.normalized, '966501234567');
      });

      test('normalizes local 9-digit Saudi number starting with 5', () {
        const phone = PhoneNumber('501234567');

        expect(phone.normalized, '966501234567');
      });

      test('normalizes +966 international format', () {
        const phone = PhoneNumber('+966 50 123 4567');

        expect(phone.normalized, '966501234567');
      });

      test('normalizes 00966 international format', () {
        const phone = PhoneNumber('00966 50-123-4567');

        expect(phone.normalized, '966501234567');
      });

      test('normalizes already-normalized Saudi digits without mutation', () {
        const phone = PhoneNumber('966501234567');

        expect(phone.normalized, '966501234567');
      });
    });

    group('Normalization — formatting hygiene', () {
      test('returns empty string for blank or whitespace-only input', () {
        expect(const PhoneNumber('').normalized, '');
        expect(const PhoneNumber('   ').normalized, '');
        expect(const PhoneNumber('\t\n').normalized, '');
      });

      test('strips non-digit characters gracefully from mixed input', () {
        const phone = PhoneNumber('  +967-77#123@4567!  ');

        expect(phone.normalized, '967771234567');
      });

      test('returns empty when no digits remain after stripping', () {
        expect(const PhoneNumber('+-() --').normalized, '');
        expect(const PhoneNumber('abc-def').normalized, '');
      });

      test('trims surrounding whitespace before normalization', () {
        const phone = PhoneNumber('  0771234567  ');

        expect(phone.normalized, '967771234567');
      });
    });

    group('Validation', () {
      test('accepts valid Yemeni mobile numbers for all operator prefixes', () {
        for (final prefix in ['71', '73', '77', '78']) {
          final phone = PhoneNumber('0${prefix}1234567');

          expect(phone.isValid, isTrue, reason: 'prefix $prefix should be valid');
        }
      });

      test('rejects Yemen numbers with unsupported operator prefixes', () {
        const phone = PhoneNumber('0701234567');

        expect(phone.isValid, isFalse);
      });

      test('rejects Yemen numbers with incorrect length after normalization', () {
        expect(const PhoneNumber('96777123456').isValid, isFalse);
        expect(const PhoneNumber('9677712345678').isValid, isFalse);
      });

      test('accepts valid Saudi mobile numbers', () {
        expect(const PhoneNumber('0501234567').isValid, isTrue);
        expect(const PhoneNumber('+966 55 987 6543').isValid, isTrue);
      });

      test('rejects Saudi numbers that do not start with 5 after country code', () {
        expect(const PhoneNumber('966401234567').isValid, isFalse);
      });

      test('rejects Saudi numbers with incorrect length after normalization', () {
        expect(const PhoneNumber('96650123456').isValid, isFalse);
        expect(const PhoneNumber('9665012345678').isValid, isFalse);
      });

      test('rejects empty, too short, and too long numbers per E.164 bounds', () {
        expect(const PhoneNumber('').isValid, isFalse);
        expect(const PhoneNumber('123456').isValid, isFalse);
        expect(PhoneNumber('1' * 16).isValid, isFalse);
      });

      test('isEmpty and isNotEmpty reflect raw input trimming', () {
        expect(const PhoneNumber('').isEmpty, isTrue);
        expect(const PhoneNumber('   ').isEmpty, isTrue);
        expect(const PhoneNumber('0771234567').isEmpty, isFalse);
        expect(const PhoneNumber('0771234567').isNotEmpty, isTrue);
      });
    });

    group('Country code detection', () {
      test('detects Yemen and Saudi country codes from normalized digits', () {
        expect(const PhoneNumber('0771234567').countryCode, '967');
        expect(const PhoneNumber('0501234567').countryCode, '966');
      });

      test('returns null for unrecognized country codes', () {
        expect(const PhoneNumber('+1 234 567 8900').countryCode, isNull);
      });
    });

    group('Deep links', () {
      test('generates WhatsApp and tel links for valid numbers', () {
        const phone = PhoneNumber('0771234567');

        expect(phone.whatsAppLink, 'https://wa.me/967771234567');
        expect(phone.telLink, 'tel:+967771234567');
      });

      test('returns empty deep links for invalid numbers', () {
        const phone = PhoneNumber('invalid');

        expect(phone.whatsAppLink, '');
        expect(phone.telLink, '');
      });
    });

    group('Equality', () {
      test('equates different raw inputs that normalize to the same digits', () {
        const local = PhoneNumber('0771234567');
        const international = PhoneNumber('+967 77 123 4567');

        expect(local, equals(international));
        expect(local.hashCode, equals(international.hashCode));
      });

      test('differs when normalized digits differ', () {
        const yemen = PhoneNumber('0771234567');
        const saudi = PhoneNumber('0501234567');

        expect(yemen, isNot(equals(saudi)));
      });
    });

    group('Negative and edge cases', () {
      test('rejects Yemen mobile with unsupported operator 72', () {
        expect(const PhoneNumber('0721234567').isValid, isFalse);
      });

      test('rejects Yemen landline 01 prefix that slips through as generic international', () {
        const phone = PhoneNumber('0112345678');
        expect(phone.normalized, '0112345678');
        expect(phone.isValid, isTrue);
        expect(phone.countryCode, isNull);
      });

      test('Saudi landline with country code fails Saudi mobile validation', () {
        expect(const PhoneNumber('966112345678').isValid, isFalse);
      });

      test('collapses duplicated Yemen country code prefixes', () {
        expect(
          const PhoneNumber('967967771234567').normalized,
          '967771234567',
        );
        expect(
          const PhoneNumber('009670967771234567').normalized,
          '967771234567',
        );
      });

      test('collapses duplicated Saudi country code prefixes', () {
        expect(
          const PhoneNumber('966966501234567').normalized,
          '966501234567',
        );
      });

      test('garbage input yields empty normalized and invalid', () {
        const garbage = PhoneNumber('not-a-phone!!!');
        expect(garbage.normalized, '');
        expect(garbage.isValid, isFalse);
        expect(garbage.whatsAppLink, '');
        expect(garbage.telLink, '');
      });

      test('detects Egypt country code without validating as Yemen or Saudi', () {
        expect(const PhoneNumber('201012345678').countryCode, '20');
        expect(const PhoneNumber('201012345678').isValid, isTrue);
      });

      test('partial digit strings stay un-prefixed and fail validation', () {
        expect(const PhoneNumber('77').normalized, '77');
        expect(const PhoneNumber('77').isValid, isFalse);
      });
    });
  });
}
