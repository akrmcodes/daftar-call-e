import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';

/// Canonical definitions for system-seeded currencies.
///
/// Used by database seeding and presentation fallbacks when the currency
/// catalog has not yet been loaded from Drift.
abstract final class BuiltInCurrencies {
  static const Currency yer = Currency(
    id: 'seed-yer',
    code: 'YER',
    symbol: '﷼',
    nameAr: 'ريال يمني',
    nameEn: 'Yemeni Rial',
    decimalPlaces: CurrencyPrecision.yerDecimalPlaces,
    isBuiltIn: true,
  );

  static const Currency sar = Currency(
    id: 'seed-sar',
    code: 'SAR',
    /// Official Unicode SAUDI RIYAL SIGN (U+20C1). UI renders the SAMA SVG.
    symbol: '\u20C1',
    nameAr: 'ريال سعودي',
    nameEn: 'Saudi Riyal',
    decimalPlaces: CurrencyPrecision.sarDecimalPlaces,
    isBuiltIn: true,
  );

  static const Currency usd = Currency(
    id: 'seed-usd',
    code: 'USD',
    symbol: r'$',
    nameAr: 'دولار أمريكي',
    nameEn: 'US Dollar',
    decimalPlaces: CurrencyPrecision.usdDecimalPlaces,
    isBuiltIn: true,
  );

  static const List<Currency> all = [yer, sar, usd];
}
