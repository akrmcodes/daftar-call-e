import 'package:daftar/domain/enums/day_journal_kind.dart';
import 'package:drift/drift.dart';

/// Append-only AI day journal (audit of confirm-gate events, not money SoT).
///
/// No `isDeleted` / `syncVersion` — matches audit-log shape. No FK to
/// contacts or ledgers so rows survive soft-delete of those entities.
@TableIndex(name: 'idx_day_journal_local_day', columns: {#localDay})
@TableIndex(name: 'idx_day_journal_kind', columns: {#kind})
@TableIndex(name: 'idx_day_journal_created_at', columns: {#createdAt})
@TableIndex(name: 'idx_day_journal_proposal', columns: {#proposalId})
class DayJournalEntries extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Calendar day `YYYY-MM-DD` in the merchant's local timezone.
  TextColumn get localDay => text()();

  /// What happened (confirm, skip, note, …).
  TextColumn get kind => textEnum<DayJournalKind>()();

  /// JSON payload for the event (proposal snapshot, notes, …).
  TextColumn get payloadJson => text()();

  /// Optional ledger UUID at the time of the event.
  TextColumn get ledgerId => text().nullable()();

  /// Optional contact UUID at the time of the event.
  TextColumn get contactId => text().nullable()();

  /// Optional amount in integer minor units. Never real/double.
  IntColumn get amount => integer().nullable()();

  /// Optional ISO 4217 currency code for [amount].
  TextColumn get currencyCode => text().nullable()();

  /// Optional confirm-gate proposal id.
  TextColumn get proposalId => text().nullable()();

  /// Optional agent session that produced this row.
  TextColumn get sessionId => text().nullable()();

  /// UTC timestamp of append.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
