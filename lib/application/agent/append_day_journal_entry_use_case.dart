import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/day_journal_entry.dart';
import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:daftar/domain/repositories/day_journal_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Appends a day-journal row after validating calendar day and integer money.
class AppendDayJournalEntryUseCase {
  /// Creates the use case.
  const AppendDayJournalEntryUseCase(this._dayJournalRepository);

  final DayJournalRepository _dayJournalRepository;

  static final RegExp _localDayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Validates then persists an append-only journal entry.
  ///
  /// [amount] must be integer minor units (the Dart type is already `int?`);
  /// negative values are rejected.
  Future<Either<Failure, DayJournalEntry>> execute({
    required String localDay,
    required DayJournalKind kind,
    required String payloadJson,
    String? ledgerId,
    String? contactId,
    int? amount,
    String? currencyCode,
    String? proposalId,
    String? sessionId,
  }) async {
    if (!_localDayPattern.hasMatch(localDay)) {
      return const Left(
        ValidationFailure(
          'localDay must be YYYY-MM-DD.',
          code: 'invalid_local_day',
        ),
      );
    }

    if (amount != null && amount < 0) {
      return const Left(
        ValidationFailure(
          'Journal amount must be a non-negative integer in minor units.',
          code: 'invalid_journal_amount',
        ),
      );
    }

    final trimmedPayload = payloadJson.trim();
    if (trimmedPayload.isEmpty) {
      return const Left(
        ValidationFailure(
          'Journal payloadJson is required.',
          code: 'journal_payload_required',
        ),
      );
    }

    final entry = DayJournalEntry(
      id: UuidUtil.generate(),
      localDay: localDay,
      kind: kind,
      payloadJson: trimmedPayload,
      createdAt: DateTime.now().toUtc(),
      ledgerId: _normalizeOptional(ledgerId),
      contactId: _normalizeOptional(contactId),
      amount: amount,
      currencyCode: _normalizeOptional(currencyCode)?.toUpperCase(),
      proposalId: _normalizeOptional(proposalId),
      sessionId: _normalizeOptional(sessionId),
    );

    return _dayJournalRepository.append(entry);
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
