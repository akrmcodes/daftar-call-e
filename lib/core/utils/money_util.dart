import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:intl/intl.dart';

/// Utility for formatting monetary amounts stored as [int] (minor / smallest
/// currency unit) into human-readable display strings.
///
/// All monetary values in Daftar are stored as [int] to prevent
/// floating-point rounding errors. This utility converts minor units into
/// grouped display strings with currency-appropriate fractional digits.
///
/// ## Usage
/// ```dart
/// MoneyUtil.formatMinorUnits(15550, 2);           // '155.50'
/// MoneyUtil.formatMinorUnits(500, 0);               // '500'
/// MoneyUtil.formatWithSymbol(15550, 2, '﷼');        // '155.50 ﷼'
/// ```
abstract final class MoneyUtil {
  static final NumberFormat _groupingFormat =
      NumberFormat.decimalPattern(AppConstants.numeralLocale);

  /// Formats [minorUnits] with thousands grouping and [decimalPlaces].
  static String formatAmount(int minorUnits, int decimalPlaces) {
    return formatMinorUnits(minorUnits, decimalPlaces);
  }

  /// Formats [minorUnits] using the precision rule for [currencyCode].
  static String formatMinorUnitsForCode(int minorUnits, String currencyCode) {
    return formatMinorUnits(
      minorUnits,
      CurrencyPrecision.decimalPlacesForCode(currencyCode),
    );
  }

  /// Formats [minorUnits] with thousands grouping and [decimalPlaces].
  static String formatMinorUnits(int minorUnits, int decimalPlaces) {
    if (decimalPlaces <= 0) {
      return _groupingFormat.format(minorUnits);
    }

    final isNegative = minorUnits < 0;
    final abs = minorUnits.abs();
    final divisor = CurrencyPrecision.minorUnitFactor(decimalPlaces);
    final wholePart = abs ~/ divisor;
    final fractionalPart = abs % divisor;
    final groupedWhole = _groupingFormat.format(wholePart);
    final fractionalText =
        fractionalPart.toString().padLeft(decimalPlaces, '0');
    final body = '$groupedWhole.$fractionalText';
    return isNegative ? '-$body' : body;
  }

  /// Formats [minorUnits] with a currency [symbol] appended.
  static String formatWithSymbol(
    int minorUnits,
    int decimalPlaces,
    String symbol,
  ) {
    return '${formatMinorUnits(minorUnits, decimalPlaces)} $symbol';
  }

  /// Formats [minorUnits] with a [symbol] using [currencyCode] precision.
  static String formatWithSymbolForCode(
    int minorUnits,
    String currencyCode,
    String symbol,
  ) {
    return '${formatMinorUnitsForCode(minorUnits, currencyCode)} $symbol';
  }

  /// Formats [minorUnits] with Western digits and thousands grouping.
  static String formatArabic(int minorUnits, int decimalPlaces) {
    return formatGrouped(minorUnits, decimalPlaces);
  }

  /// Alias for [formatMinorUnits].
  static String formatGrouped(int minorUnits, int decimalPlaces) {
    return formatMinorUnits(minorUnits, decimalPlaces);
  }

  /// Parses a display amount into minor units for [decimalPlaces].
  ///
  /// Returns `null` when the input is empty or not a positive value.
  static int? parseMinorUnits(String raw, int decimalPlaces) {
    final parsed = CsvParserUtil.parseAmountToMinorUnitsWithFractionDigits(
      raw,
      decimalPlaces,
    );
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  /// Parses a display amount into minor units for [currencyCode].
  static int? parseMinorUnitsForCode(String raw, String currencyCode) {
    return parseMinorUnits(
      raw,
      CurrencyPrecision.decimalPlacesForCode(currencyCode),
    );
  }

  /// Parses a grouped integer amount string (e.g. `15,550`) into [int].
  ///
  /// Returns `null` when the input is empty or not a positive integer.
  static int? parseGroupedPositiveInteger(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('-')) {
      return null;
    }
    final digits = CsvParserUtil.normalizeDigitsForParse(raw)
        .replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(digits);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }
}
