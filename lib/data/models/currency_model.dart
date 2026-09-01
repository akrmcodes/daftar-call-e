import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/currency.dart' as domain;

/// Data-layer representation of a currency.
class CurrencyModel {
  /// Creates a currency model.
  const CurrencyModel({
    required this.id,
    required this.code,
    required this.symbol,
    required this.nameAr,
    required this.nameEn,
    required this.decimalPlaces,
    this.isBuiltIn = false,
    this.isActive = true,
  });

  /// Creates a model from the domain entity.
  factory CurrencyModel.fromDomain(domain.Currency currency) {
    return CurrencyModel(
      id: currency.id,
      code: currency.code,
      symbol: currency.symbol,
      nameAr: currency.nameAr,
      nameEn: currency.nameEn,
      decimalPlaces: currency.decimalPlaces,
      isBuiltIn: currency.isBuiltIn,
      isActive: currency.isActive,
    );
  }

  /// Unique identifier.
  final String id;

  /// ISO currency code.
  final String code;

  /// Display symbol.
  final String symbol;

  /// Arabic display name.
  final String nameAr;

  /// English display name.
  final String nameEn;

  /// Decimal places for display formatting.
  final int decimalPlaces;

  /// Whether this is a built-in currency.
  final bool isBuiltIn;

  /// Whether this currency is active in the UI.
  final bool isActive;

  /// Converts this model back to the domain entity.
  domain.Currency toDomain() {
    return domain.Currency(
      id: id,
      code: code,
      symbol: symbol,
      nameAr: nameAr,
      nameEn: nameEn,
      decimalPlaces: decimalPlaces,
      isBuiltIn: isBuiltIn,
      isActive: isActive,
    );
  }

  /// Converts this model to the generated Drift row.
  db.Currency toDrift() {
    return db.Currency(
      id: id,
      code: code,
      symbol: symbol,
      nameAr: nameAr,
      nameEn: nameEn,
      decimalPlaces: decimalPlaces,
      isBuiltIn: isBuiltIn,
      isActive: isActive,
    );
  }

  /// Converts this model to a Drift companion.
  db.CurrenciesCompanion toCompanion() => toDrift().toCompanion(false);
}
