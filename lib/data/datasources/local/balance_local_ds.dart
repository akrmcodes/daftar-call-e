import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/balance_mapper.dart';
import 'package:daftar/data/models/balance_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for contact balance persistence.
class BalanceLocalDataSource {
  /// Creates a balance local data source.
  BalanceLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Returns all balance rows for a contact.
  Future<List<BalanceModel>> getBalanceByContact(String contactId) async {
    final rows =
        await (database.select(database.contactBalances)
              ..where((table) => table.contactId.equals(contactId))
              ..orderBy([
                (table) => drift.OrderingTerm(expression: table.currencyCode),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }

  /// Watches balance rows for a contact.
  Stream<List<BalanceModel>> watchBalanceByContact(String contactId) {
    return (database.select(database.contactBalances)
          ..where((table) => table.contactId.equals(contactId))
          ..orderBy([
            (table) => drift.OrderingTerm(expression: table.currencyCode),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) => row.toModel()).toList(growable: false),
        );
  }

  /// Watches all balance rows across contacts.
  Stream<List<BalanceModel>> watchAllBalances() {
    final balances = database.contactBalances;
    final contacts = database.contacts;
    final ledgers = database.ledgers;
    final query = database.select(balances).join([
      drift.innerJoin(
        contacts,
        contacts.id.equalsExp(balances.contactId),
      ),
      drift.innerJoin(
        ledgers,
        ledgers.id.equalsExp(contacts.ledgerId),
      ),
    ])
      ..where(
        ledgers.isDeleted.equals(false) &
            ledgers.isArchived.equals(false) &
            ledgers.isUserArchived.equals(false),
      )
      ..orderBy([
        drift.OrderingTerm(expression: balances.currencyCode),
        drift.OrderingTerm(expression: balances.contactId),
      ]);
    return query.watch().map(
      (rows) => rows
          .map((row) => row.readTable(balances).toModel())
          .toList(growable: false),
    );
  }

  Stream<List<BalanceModel>> watchBalancesByLedger(String ledgerId) {
    final balances = database.contactBalances;
    final contacts = database.contacts;
    final ledgers = database.ledgers;
    final query = database.select(balances).join([
      drift.innerJoin(
        contacts,
        contacts.id.equalsExp(balances.contactId),
      ),
      drift.innerJoin(
        ledgers,
        ledgers.id.equalsExp(contacts.ledgerId),
      ),
    ])
      ..where(
        ledgers.id.equals(ledgerId) &
            ledgers.isDeleted.equals(false) &
            contacts.isDeleted.equals(false) &
            contacts.isArchived.equals(false),
      )
      ..orderBy([
        drift.OrderingTerm(expression: balances.currencyCode),
        drift.OrderingTerm(expression: balances.contactId),
      ]);
    return query.watch().map(
      (rows) => rows
          .map((row) => row.readTable(balances).toModel())
          .toList(growable: false),
    );
  }

  /// Inserts or updates a balance row.
  Future<BalanceModel> upsertBalance(BalanceModel balance) async {
    await database
        .into(database.contactBalances)
        .insertOnConflictUpdate(balance.toDrift());
    return balance;
  }

  Future<void> bulkUpsertBalances(List<BalanceModel> balances) async {
    if (balances.isEmpty) {
      return;
    }

    await database.batch((batch) {
      for (final balance in balances) {
        batch.insert(
          database.contactBalances,
          balance.toDrift(),
          onConflict: drift.DoUpdate((_) => balance.toDrift()),
        );
      }
    });
  }
}
