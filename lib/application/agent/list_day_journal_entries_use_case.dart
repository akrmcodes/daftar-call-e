import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/repositories/day_journal_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Lists day-journal rows for a calendar day.
class ListDayJournalEntriesUseCase {
  /// Creates the use case.
  const ListDayJournalEntriesUseCase(this._dayJournalRepository);

  final DayJournalRepository _dayJournalRepository;

  static final RegExp _localDayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Returns entries for [localDay] (`YYYY-MM-DD`), oldest first.
  Future<Either<Failure, List<DayJournalEntry>>> execute(
    String localDay,
  ) async {
    if (!_localDayPattern.hasMatch(localDay)) {
      return const Left(
        ValidationFailure(
          'localDay must be YYYY-MM-DD.',
          code: 'invalid_local_day',
        ),
      );
    }

    return _dayJournalRepository.listByLocalDay(localDay);
  }
}
