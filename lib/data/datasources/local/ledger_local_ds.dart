import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/ledger_mapper.dart';
import 'package:daftar/data/models/ledger_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for ledger persistence.
class LedgerLocalDataSource {
  /// Creates a ledger local data source.
  LedgerLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Creates a ledger row.
  Future<LedgerModel> createLedger(LedgerModel ledger) async {
    await database.into(database.ledgers).insert(ledger.toDrift());
    return ledger;
  }

  /// Updates an existing ledger row.
  Future<LedgerModel> updateLedger(LedgerModel ledger) async {
    final updatedRows =
        await (database.update(database.ledgers)
              ..where((table) => table.id.equals(ledger.id)))
            .write(ledger.toCompanion());

    if (updatedRows == 0) {
      throw StateError('Ledger not found: ${ledger.id}');
    }

    return ledger;
  }

  /// Soft-deletes a ledger row.
  Future<LedgerModel> deleteLedger(String ledgerId) async {
    final existing = await getLedgerById(ledgerId);
    if (existing == null) {
      throw StateError('Ledger not found: $ledgerId');
    }

    final deleted = LedgerModel(
      id: existing.id,
      name: existing.name,
      type: existing.type,
      icon: existing.icon,
      color: existing.color,
      sortOrder: existing.sortOrder,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
      isDeleted: true,
      syncVersion: existing.syncVersion + 1,
    );

    await updateLedger(deleted);
    return deleted;
  }

  /// Watches all active ledgers sorted by sort order.
  Stream<List<LedgerModel>> watchAllLedgers() {
    return (database.select(database.ledgers)
          ..where(
            (table) =>
                table.isDeleted.equals(false) &
                table.isArchived.equals(false) &
                table.isUserArchived.equals(false),
          )
          ..orderBy([
            (table) => drift.OrderingTerm(expression: table.sortOrder),
            (table) => drift.OrderingTerm(expression: table.name),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) => row.toModel()).toList(growable: false),
        );
  }

  Stream<List<LedgerModel>> watchArchivedLedgers() {
    return (database.select(database.ledgers)
          ..where(
            (table) =>
                table.isDeleted.equals(false) &
                table.isUserArchived.equals(true),
          )
          ..orderBy([
            (table) => drift.OrderingTerm(expression: table.sortOrder),
            (table) => drift.OrderingTerm(expression: table.name),
          ]))
        .watch()
        .map(
          (rows) => rows.map((row) => row.toModel()).toList(growable: false),
        );
  }

  Future<int> countUserArchivedLedgers() async {
    final result = await database
        .customSelect(
          'SELECT COUNT(*) AS cnt FROM ledgers '
          'WHERE is_deleted = 0 AND is_user_archived = 1',
          readsFrom: {database.ledgers},
        )
        .getSingle();
    return result.read<int>('cnt');
  }

  /// Returns a ledger by ID.
  Future<LedgerModel?> getLedgerById(String ledgerId) async {
    final row = await (database.select(
      database.ledgers,
    )..where((table) => table.id.equals(ledgerId))).getSingleOrNull();
    return row?.toModel();
  }
}
