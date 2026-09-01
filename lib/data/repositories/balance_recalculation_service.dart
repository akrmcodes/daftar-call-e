import 'package:daftar/data/datasources/local/balance_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/transaction_mapper.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/repositories/balance_calculator.dart';
import 'package:drift/drift.dart' as drift;

class BalanceRecalculationService {
  BalanceRecalculationService({
    required db.AppDatabase database,
    required BalanceLocalDataSource balanceLocalDataSource,
  }) : _database = database,
       _balanceLocalDataSource = balanceLocalDataSource;

  final db.AppDatabase _database;
  final BalanceLocalDataSource _balanceLocalDataSource;

  Future<List<BalanceModel>> recalculateBalancesForContact({
    required String contactId,
    required DateTime lastUpdatedAt,
  }) async {
    final rows =
        await (_database.select(_database.transactions)
              ..where((table) => table.contactId.equals(contactId))
              ..where((table) => table.isDeleted.equals(false))
              ..where((table) => table.isArchived.equals(false))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.transactionDate,
                  mode: drift.OrderingMode.desc,
                ),
              ]))
            .get();

    final balances = calculateContactBalances(
      contactId: contactId,
      transactions: rows.map((row) => row.toModel()),
      lastUpdatedAt: lastUpdatedAt,
    );

    for (final balance in balances) {
      await _balanceLocalDataSource.upsertBalance(balance);
    }

    await _deleteStaleBalances(contactId, balances);

    return balances;
  }

  Future<void> _deleteStaleBalances(
    String contactId,
    List<BalanceModel> balances,
  ) async {
    if (balances.isEmpty) {
      await (_database.delete(
        _database.contactBalances,
      )..where((table) => table.contactId.equals(contactId))).go();
      return;
    }

    final activeCurrencies = balances.map((balance) => balance.currencyCode);
    await (_database.delete(_database.contactBalances)
          ..where((table) => table.contactId.equals(contactId))
          ..where((table) => table.currencyCode.isNotIn(activeCurrencies)))
        .go();
  }
}
