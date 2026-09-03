import 'package:daftar/data/datasources/local/tables/contacts_table.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:drift/drift.dart';

/// Display-only promise card. No ledger movement.
@TableIndex(name: 'idx_collection_promises_contact_id', columns: {#contactId})
@TableIndex(name: 'idx_collection_promises_run_id', columns: {#runId})
class CollectionPromises extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// FK to [Contacts].
  TextColumn get contactId => text().references(Contacts, #id)();

  /// CALL-E call.id from the parent run.
  TextColumn get runId => text()();

  /// Promised amount in smallest currency unit.
  IntColumn get amountMinor => integer()();

  /// ISO currency code.
  TextColumn get currencyCode => text()();

  /// Merchant calendar day YYYY-MM-DD.
  TextColumn get promisedDate => text()();

  /// Promise lifecycle for UI only.
  TextColumn get status => textEnum<CollectionPromiseStatus>()();

  /// UTC insert time.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC last mutation.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Sync conflict resolution version.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  String get tableName => 'collection_promises';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
