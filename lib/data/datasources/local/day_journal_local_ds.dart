import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/day_journal_entry_mapper.dart';
import 'package:daftar/data/models/day_journal_entry_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for append-only day-journal persistence.
class DayJournalLocalDataSource {
  /// Creates a day-journal local data source.
  DayJournalLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Inserts a journal row. Never updates existing rows.
  Future<DayJournalEntryModel> insertEntry(DayJournalEntryModel entry) async {
    await database.into(database.dayJournalEntries).insert(entry.toDrift());
    return entry;
  }

  /// Returns rows for [localDay], oldest first.
  Future<List<DayJournalEntryModel>> listByLocalDay(String localDay) async {
    final rows =
        await (database.select(database.dayJournalEntries)
              ..where((table) => table.localDay.equals(localDay))
              ..orderBy([
                (table) => drift.OrderingTerm(expression: table.createdAt),
                (table) => drift.OrderingTerm(expression: table.id),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }
}
