import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'day_journal_entry.freezed.dart';

/// Append-only day-journal row (AI audit of confirm-gate events).
///
/// Not the money source of truth — committed amounts still go through
/// existing transaction / contact / ledger use cases. [amount] is integer
/// minor units only.
@freezed
abstract class DayJournalEntry with _$DayJournalEntry {
  const factory DayJournalEntry({
    required String id,
    required String localDay,
    required DayJournalKind kind,
    required String payloadJson,
    required DateTime createdAt,
    String? ledgerId,
    String? contactId,
    int? amount,
    String? currencyCode,
    String? proposalId,
    String? sessionId,
  }) = _DayJournalEntry;
}
