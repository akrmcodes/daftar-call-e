import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/day_journal_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/day_journal_entry_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/repositories/day_journal_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [DayJournalRepository].
class DayJournalRepositoryImpl implements DayJournalRepository {
  /// Creates a day-journal repository implementation.
  DayJournalRepositoryImpl({
    required DayJournalLocalDataSource dayJournalLocalDataSource,
  }) : _dayJournalLocalDataSource = dayJournalLocalDataSource;

  final DayJournalLocalDataSource _dayJournalLocalDataSource;

  db.AppDatabase get _database => _dayJournalLocalDataSource.database;

  @override
  Future<Either<Failure, DayJournalEntry>> append(
    DayJournalEntry entry,
  ) async {
    try {
      final model = DayJournalEntryModel.fromDomain(entry);
      await _database.transaction(() async {
        await _dayJournalLocalDataSource.insertEntry(model);
      });
      return Right(model.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<DayJournalEntry>>> listByLocalDay(
    String localDay,
  ) async {
    try {
      final rows = await _dayJournalLocalDataSource.listByLocalDay(localDay);
      return Right(
        rows.map((row) => row.toDomain()).toList(growable: false),
      );
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}
