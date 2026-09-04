import 'package:daftar/domain/constants/promised_amount_minor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromisedAmountMinor', () {
    test('accepts JSON int', () {
      expect(PromisedAmountMinor.tryParse(1500), 1500);
      expect(PromisedAmountMinor.isInvalidPresent(1500), isFalse);
    });

    test('accepts whole JSON number', () {
      expect(PromisedAmountMinor.tryParse(1500.0), 1500);
      expect(PromisedAmountMinor.isInvalidPresent(1500.0), isFalse);
    });

    test('rejects remainder and bool', () {
      expect(PromisedAmountMinor.tryParse(1500.5), isNull);
      expect(PromisedAmountMinor.isInvalidPresent(1500.5), isTrue);
      expect(PromisedAmountMinor.tryParse(true), isNull);
      expect(PromisedAmountMinor.isInvalidPresent(true), isTrue);
    });

    test('null is absence not invalid', () {
      expect(PromisedAmountMinor.tryParse(null), isNull);
      expect(PromisedAmountMinor.isInvalidPresent(null), isFalse);
    });
  });
}
