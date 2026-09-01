import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/currency_model.dart';
import 'package:daftar/domain/entities/currency.dart' as domain;

/// Seamless conversions for currency domain, data, and Drift types.
extension CurrencyDomainMapper on domain.Currency {
  /// Converts a domain currency to the data-layer model.
  CurrencyModel toModel() => CurrencyModel.fromDomain(this);

  /// Converts a domain currency to a generated Drift row.
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

  /// Converts a domain currency to a Drift companion.
  db.CurrenciesCompanion toCompanion() => toDrift().toCompanion(false);
}

/// Seamless conversions for generated Drift currency rows.
extension CurrencyDriftMapper on db.Currency {
  /// Converts a Drift currency row to the data-layer model.
  CurrencyModel toModel() => CurrencyModel(
    id: id,
    code: code,
    symbol: symbol,
    nameAr: nameAr,
    nameEn: nameEn,
    decimalPlaces: decimalPlaces,
    isBuiltIn: isBuiltIn,
    isActive: isActive,
  );

  /// Converts a Drift currency row back to the domain entity.
  domain.Currency toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift currency companions.
extension CurrencyCompanionMapper on db.CurrenciesCompanion {
  /// Converts a Drift currency companion to the data-layer model.
  CurrencyModel toModel() => CurrencyModel(
    id: id.value,
    code: code.value,
    symbol: symbol.value,
    nameAr: nameAr.value,
    nameEn: nameEn.value,
    decimalPlaces: decimalPlaces.value,
    isBuiltIn: isBuiltIn.present && isBuiltIn.value,
    isActive: !isActive.present || isActive.value,
  );

  /// Converts a Drift currency companion to a generated Drift row.
  db.Currency toDrift() => toModel().toDrift();

  /// Converts a Drift currency companion back to the domain entity.
  domain.Currency toDomain() => toModel().toDomain();
}
