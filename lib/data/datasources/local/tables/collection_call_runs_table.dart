import 'package:daftar/data/datasources/local/tables/contacts_table.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:drift/drift.dart';

/// Per-contact CALL-E run row (runId := CALL-E call.id).
@TableIndex(name: 'idx_collection_call_runs_batch_id', columns: {#batchId})
@TableIndex(name: 'idx_collection_call_runs_contact_id', columns: {#contactId})
@TableIndex(name: 'idx_collection_call_runs_run_id', columns: {#runId}, unique: true)
class CollectionCallRuns extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Parent J.9 batch UUID.
  TextColumn get batchId => text()();

  /// FK to [Contacts].
  TextColumn get contactId => text().references(Contacts, #id)();

  /// ISO 3166-1 alpha-2 region sent to CALL-E.
  TextColumn get region => text()();

  /// BCP-47-ish locale (e.g. en-US, ar).
  TextColumn get locale => text()();

  /// CALL-E call.id. Null until run-batch queues.
  TextColumn get runId => text().nullable()();

  /// J.9 outcome when terminal.
  TextColumn get outcome => textEnum<CallRunOutcome>().nullable()();

  /// Promised amount in smallest currency unit.
  IntColumn get promisedAmountMinor => integer().nullable()();

  /// ISO currency for [promisedAmountMinor].
  TextColumn get promisedCurrency => text().nullable()();

  /// Merchant calendar day YYYY-MM-DD.
  TextColumn get promisedDate => text().nullable()();

  /// Structured result flag from CALL-E.
  BoolColumn get acknowledgedHold => boolean().nullable()();

  /// Evidence quote for device display only. Never log.
  TextColumn get evidenceQuote => text().nullable()();

  /// CALL-E status pass-through (queued, completed, …).
  TextColumn get rawStatus => text().nullable()();

  /// 0 = first create; 1 = one no-answer/voicemail retry.
  IntColumn get retryCount =>
      integer().withDefault(const Constant(0))();

  /// UTC insert time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC last mutation.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Sync conflict resolution version.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'collection_call_runs';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
