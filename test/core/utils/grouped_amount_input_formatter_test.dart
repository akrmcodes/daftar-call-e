import 'package:daftar/core/utils/grouped_amount_input_formatter.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _format(
  GroupedAmountInputFormatter formatter,
  String oldText,
  String newText, {
  int? cursor,
}) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursor ?? newText.length,
      ),
    ),
  );
}

void main() {
  group('GroupedAmountInputFormatter', () {
    const integerFormatter = GroupedAmountInputFormatter();
    const decimalFormatter = GroupedAmountInputFormatter(
      allowDecimal: true,
      maxFractionDigits: 2,
    );

    test('groups integers as the user types', () {
      expect(_format(integerFormatter, '', '1').text, '1');
      expect(_format(integerFormatter, '1', '12').text, '12');
      expect(_format(integerFormatter, '12', '123').text, '123');
      expect(_format(integerFormatter, '123', '1234').text, '1,234');
      expect(_format(integerFormatter, '1,234', '12345').text, '12,345');
      expect(_format(integerFormatter, '12,345', '1234567').text, '1,234,567');
    });

    test('normalizes Arabic-Indic digits while grouping', () {
      expect(_format(integerFormatter, '', '١٢٣٤').text, '1,234');
    });

    test('formats pasted grouped values', () {
      expect(_format(integerFormatter, '', '15,550').text, '15,550');
    });

    test('groups integer portion and preserves decimals', () {
      expect(_format(decimalFormatter, '', '1234.5').text, '1,234.5');
      expect(_format(decimalFormatter, '1,234.', '1,234.56').text, '1,234.56');
    });

    test('caps fractional digits', () {
      expect(_format(decimalFormatter, '', '10.999').text, '10.99');
    });

    test('preserves trailing decimal separator while typing', () {
      expect(_format(decimalFormatter, '1,234', '1234.').text, '1,234.');
    });
  });

  group('MoneyUtil.parseMinorUnits', () {
    test('parses fractional display amounts into minor units', () {
      expect(MoneyUtil.parseMinorUnits('500.50', 2), 50050);
      expect(MoneyUtil.parseMinorUnits('1,234.56', 2), 123456);
    });
  });

  group('MoneyUtil.parseGroupedPositiveInteger', () {
    test('parses grouped integers', () {
      expect(MoneyUtil.parseGroupedPositiveInteger('15,550'), 15550);
      expect(MoneyUtil.parseGroupedPositiveInteger('١٥٥٥٠'), 15550);
    });

    test('returns null for empty or non-positive values', () {
      expect(MoneyUtil.parseGroupedPositiveInteger(''), isNull);
      expect(MoneyUtil.parseGroupedPositiveInteger('0'), isNull);
      expect(MoneyUtil.parseGroupedPositiveInteger('abc'), isNull);
    });
  });
}
