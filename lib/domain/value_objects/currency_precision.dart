/// Currency-specific decimal precision rules for monetary display and input.
///
/// All arithmetic remains in minor units ([int]). This type only governs how
/// many fractional digits a currency exposes in the UI and how user input is
/// parsed into minor units.
///
/// **Business rules (built-in):**
/// - [yerDecimalPlaces] — Yemeni Rial: whole rials only in daily trade.
/// - [sarDecimalPlaces] / [usdDecimalPlaces] — halalas and cents (2 dp).
abstract final class CurrencyPrecision {
  /// Yemeni Rial — no fractional units in merchant ledgers.
  static const int yerDecimalPlaces = 0;

  /// Saudi Riyal — 100 halalas per riyal.
  static const int sarDecimalPlaces = 2;

  /// US Dollar — 100 cents per dollar.
  static const int usdDecimalPlaces = 2;

  /// Default precision for unknown or custom currencies.
  static const int defaultDecimalPlaces = 2;

  /// Returns the number of decimal places for [currencyCode].
  ///
  /// Built-in ISO codes use explicit overrides. All other codes default to
  /// [defaultDecimalPlaces] until a currency record supplies a value.
  static int decimalPlacesForCode(String currencyCode) {
    switch (currencyCode.trim().toUpperCase()) {
      case 'YER':
        return yerDecimalPlaces;
      case 'SAR':
        return sarDecimalPlaces;
      case 'USD':
        return usdDecimalPlaces;
      default:
        return defaultDecimalPlaces;
    }
  }

  /// Whether the amount pad / text field should accept a decimal separator.
  static bool allowsFractionalInput(String currencyCode) =>
      decimalPlacesForCode(currencyCode) > 0;

  /// Returns 10^[decimalPlaces] as an integer minor-unit divisor.
  static int minorUnitFactor(int decimalPlaces) {
    if (decimalPlaces <= 0) {
      return 1;
    }
    var result = 1;
    for (var i = 0; i < decimalPlaces; i++) {
      result *= 10;
    }
    return result;
  }

  /// Converts [minorUnits] to major units for animated counters.
  ///
  /// Uses integer decomposition so powers-of-ten divisors stay exact in
  /// [double] — safe for UI animation only, never for persistence.
  static double toMajorUnits(int minorUnits, int decimalPlaces) {
    if (decimalPlaces <= 0) {
      return minorUnits.toDouble();
    }

    final divisor = minorUnitFactor(decimalPlaces);
    final abs = minorUnits.abs();
    final whole = abs ~/ divisor;
    final fractional = abs % divisor;
    final major = whole + fractional / divisor;
    return minorUnits < 0 ? -major : major;
  }
}
