import 'package:daftar/core/utils/money_util.dart';

/// Extensions on [int] for quick currency formatting.
///
/// Provides convenience methods to format integer monetary amounts
/// without importing and calling [MoneyUtil] directly.
///
/// ## Usage
/// ```dart
/// 15550.asCurrency(2)           // '155.50'
/// 15550.asCurrencyWith('﷼', 2)  // '155.50 ﷼'
/// 15550.asCurrencyArabic(2)    // '155.50'
/// ```
extension CurrencyFormatting on int {
  /// Formats this integer as a currency display string.
  ///
  /// Formats this minor-unit amount with [decimalPlaces] fractional digits.
  String asCurrency(int decimalPlaces) {
    return MoneyUtil.formatAmount(this, decimalPlaces);
  }

  /// Formats this integer as a currency string with a [symbol].
  ///
  /// Example: `15550.asCurrencyWith('﷼', 2)` → `'155.50 ﷼'`
  String asCurrencyWith(String symbol, int decimalPlaces) {
    return MoneyUtil.formatWithSymbol(this, decimalPlaces, symbol);
  }

  /// Formats this integer with Western digits and grouping.
  ///
  /// Example: `15550.asCurrencyArabic(2)` → `'155.50'`
  String asCurrencyArabic(int decimalPlaces) {
    return MoneyUtil.formatArabic(this, decimalPlaces);
  }

  /// Formats this integer with Western thousands grouping.
  ///
  /// Example: `15550.asCurrencyGrouped(2)` → `'155.50'`
  String asCurrencyGrouped(int decimalPlaces) {
    return MoneyUtil.formatGrouped(this, decimalPlaces);
  }
}
