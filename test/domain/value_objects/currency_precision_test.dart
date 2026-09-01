import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyPrecision', () {
    test('maps built-in currencies to merchant precision rules', () {
      expect(CurrencyPrecision.decimalPlacesForCode('YER'), 0);
      expect(CurrencyPrecision.decimalPlacesForCode('SAR'), 2);
      expect(CurrencyPrecision.decimalPlacesForCode('USD'), 2);
      expect(CurrencyPrecision.decimalPlacesForCode('yer'), 0);
    });

    test('gates fractional input by precision', () {
      expect(CurrencyPrecision.allowsFractionalInput('YER'), isFalse);
      expect(CurrencyPrecision.allowsFractionalInput('SAR'), isTrue);
    });

    test('converts minor units to major units without precision loss', () {
      expect(CurrencyPrecision.toMajorUnits(500, 0), 500);
      expect(CurrencyPrecision.toMajorUnits(50050, 2), 500.50);
      expect(CurrencyPrecision.toMajorUnits(-1050, 2), -10.50);
    });

    group('Negative and edge cases', () {
      test('unknown currency codes default to two decimal places', () {
        expect(CurrencyPrecision.decimalPlacesForCode('EUR'), 2);
        expect(CurrencyPrecision.decimalPlacesForCode('  yer '), 0);
        expect(CurrencyPrecision.allowsFractionalInput('XYZ'), isTrue);
      });

      test('minorUnitFactor returns one for non-positive decimal places', () {
        expect(CurrencyPrecision.minorUnitFactor(0), 1);
        expect(CurrencyPrecision.minorUnitFactor(-3), 1);
      });

      test('minorUnitFactor scales by powers of ten', () {
        expect(CurrencyPrecision.minorUnitFactor(2), 100);
        expect(CurrencyPrecision.minorUnitFactor(3), 1000);
      });

      test('toMajorUnits handles zero and large whole-unit YER amounts', () {
        expect(CurrencyPrecision.toMajorUnits(0, 0), 0);
        expect(CurrencyPrecision.toMajorUnits(999999999, 0), 999999999);
      });
    });
  });
}
