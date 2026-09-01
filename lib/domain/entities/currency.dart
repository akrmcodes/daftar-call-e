import 'package:freezed_annotation/freezed_annotation.dart';

part 'currency.freezed.dart';

/// Represents a currency supported by the application.
///
/// Currencies define how monetary amounts are displayed and which
/// currency symbols to use. Built-in currencies (YER, SAR, USD) are
/// seeded on first launch and cannot be deleted. Users can add custom
/// currencies and toggle their active/inactive status.
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [code]: ISO 4217 currency code (e.g., 'YER'). Unique constraint.
/// - [symbol]: Display symbol (e.g., '﷼', '⃁', '$').
///   Saudi Riyal uses Unicode U+20C1; UI renders the official SAMA SVG.
/// - [nameAr]: Arabic display name (e.g., 'ريال يمني').
/// - [nameEn]: English display name (e.g., 'Yemeni Rial').
/// - [decimalPlaces]: Number of fractional digits for display and input
///   (e.g., 0 for YER, 2 for SAR/USD). Amounts are stored in minor units
///   derived from this precision.
/// - [isBuiltIn]: Whether this is a system-seeded currency (cannot be deleted).
/// - [isActive]: Whether this currency is available for selection in the UI.
@freezed
abstract class Currency with _$Currency {
  const factory Currency({
    required String id,
    required String code,
    required String symbol,
    required String nameAr,
    required String nameEn,
    required int decimalPlaces,
    @Default(false) bool isBuiltIn,
    @Default(true) bool isActive,
  }) = _Currency;
}
