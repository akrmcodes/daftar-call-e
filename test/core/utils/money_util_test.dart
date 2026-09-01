import 'package:daftar/core/extensions/num_extensions.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyUtil', () {
    test('formats zero-decimal currencies as grouped whole numbers', () {
      expect(MoneyUtil.formatAmount(500, 0), '500');
      expect(MoneyUtil.formatAmount(15550, 0), '15,550');
      expect(MoneyUtil.formatAmount(-15550, 0), '-15,550');
    });

    test('formats two-decimal currencies from minor units', () {
      expect(MoneyUtil.formatAmount(15550, 2), '155.50');
      expect(MoneyUtil.formatAmount(50050, 2), '500.50');
      expect(MoneyUtil.formatAmount(-1050, 2), '-10.50');
    });

    test('formats integer amounts with a currency symbol', () {
      expect(MoneyUtil.formatWithSymbol(15550, 2, '﷼'), '155.50 ﷼');
      expect(MoneyUtil.formatWithSymbol(500, 0, '﷼'), '500 ﷼');
    });

    test('formats by currency code', () {
      expect(MoneyUtil.formatMinorUnitsForCode(500, 'YER'), '500');
      expect(MoneyUtil.formatMinorUnitsForCode(50050, 'SAR'), '500.50');
    });

    test('parses display amounts into minor units', () {
      expect(MoneyUtil.parseMinorUnits('500', 0), 500);
      expect(MoneyUtil.parseMinorUnits('500.50', 2), 50050);
      expect(MoneyUtil.parseMinorUnitsForCode('15,550', 'YER'), 15550);
      expect(MoneyUtil.parseMinorUnitsForCode('1,234.56', 'USD'), 123456);
    });

    test('extension helpers mirror the shared formatter', () {
      expect(15550.asCurrencyGrouped(2), '155.50');
      expect(500.asCurrency(0), '500');
      expect((-1050).asCurrency(2), '-10.50');
      expect(15550.asCurrencyWith('﷼', 2), '155.50 ﷼');
      expect(500.asCurrencyArabic(0), '500');
    });

    group('Negative and edge cases', () {
      test('parseMinorUnits returns null for empty garbage and zero', () {
        expect(MoneyUtil.parseMinorUnits('', 2), isNull);
        expect(MoneyUtil.parseMinorUnits('abc', 2), isNull);
        expect(MoneyUtil.parseMinorUnits('0', 0), isNull);
        expect(MoneyUtil.parseGroupedPositiveInteger('0'), isNull);
      });

      test('parseMinorUnits strips minus sign for YER grouped integer path', () {
        expect(MoneyUtil.parseMinorUnitsForCode('-500', 'YER'), isNull);
        expect(MoneyUtil.parseGroupedPositiveInteger('-500'), isNull);
      });

      test('parseMinorUnits handles Arabic-Indic digits', () {
        expect(MoneyUtil.parseMinorUnitsForCode('١٥٠٠', 'YER'), 1500);
        expect(MoneyUtil.parseMinorUnits('١٥.٥٠', 2), 1550);
      });

      test('parseMinorUnits rejects excess fractional precision', () {
        expect(MoneyUtil.parseMinorUnits('10.999', 2), isNull);
      });

      test('formatMinorUnits handles int boundary magnitudes', () {
        expect(
          MoneyUtil.formatMinorUnits(9223372036854775807, 0),
          '9,223,372,036,854,775,807',
        );
      });

      test('formatWithSymbolForCode uses currency precision', () {
        expect(
          MoneyUtil.formatWithSymbolForCode(5050, 'SAR', '\u20C1'),
          '50.50 \u20C1',
        );
        expect(
          MoneyUtil.formatWithSymbolForCode(5050, 'YER', '﷼'),
          '5,050 ﷼',
        );
      });
    });
  });
}
