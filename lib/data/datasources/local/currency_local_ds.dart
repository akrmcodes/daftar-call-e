import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/currency_mapper.dart';
import 'package:daftar/data/models/currency_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for currency persistence.
class CurrencyLocalDataSource {
  /// Creates a currency local data source.
  CurrencyLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Returns all currencies.
  Future<List<CurrencyModel>> getAllCurrencies() async {
    final rows =
        await (database.select(database.currencies)..orderBy([
              (table) => drift.OrderingTerm(
                expression: table.isBuiltIn,
                mode: drift.OrderingMode.desc,
              ),
              (table) => drift.OrderingTerm(expression: table.code),
            ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Returns built-in currencies.
  Future<List<CurrencyModel>> getBuiltInCurrencies() async {
    final rows =
        await (database.select(database.currencies)
              ..where((table) => table.isBuiltIn.equals(true))
              ..orderBy([
                (table) => drift.OrderingTerm(expression: table.code),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  Future<List<CurrencyModel>> getActiveCurrencies() async {
    final rows =
        await (database.select(database.currencies)
              ..where((table) => table.isActive.equals(true))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.isBuiltIn,
                  mode: drift.OrderingMode.desc,
                ),
                (table) => drift.OrderingTerm(expression: table.code),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Adds a custom currency.
  Future<CurrencyModel> addCustomCurrency(CurrencyModel currency) async {
    final customCurrency = CurrencyModel(
      id: currency.id,
      code: currency.code,
      symbol: currency.symbol,
      nameAr: currency.nameAr,
      nameEn: currency.nameEn,
      decimalPlaces: currency.decimalPlaces,
      isActive: currency.isActive,
    );

    await database.into(database.currencies).insert(customCurrency.toDrift());
    return customCurrency;
  }

  /// Toggles the active state for a currency by code.
  Future<CurrencyModel?> toggleCurrencyActive(
    String code, {
    required bool isActive,
  }) async {
    await (database.update(
      database.currencies,
    )..where((table) => table.code.equals(code))).write(
      db.CurrenciesCompanion(
        isActive: drift.Value(isActive),
      ),
    );

    final row = await (database.select(
      database.currencies,
    )..where((table) => table.code.equals(code))).getSingleOrNull();

    return row?.toModel();
  }
}
