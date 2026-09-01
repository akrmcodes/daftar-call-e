import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:fpdart/fpdart.dart';

/// Persistence contract for append-only day-journal rows.
abstract class DayJournalRepository {
  /// Appends [entry]. Never updates or deletes existing rows.
  Future<Either<Failure, DayJournalEntry>> append(DayJournalEntry entry);

  /// Returns journal rows for calendar [localDay] (`YYYY-MM-DD`), oldest first.
  Future<Either<Failure, List<DayJournalEntry>>> listByLocalDay(
    String localDay,
  );
}
