import 'package:drift/drift.dart';

/// Drift table definition for the `sync_operations` SQLite table.
///
/// Records every remote sync operation that has been successfully applied
/// locally by the Merge Engine (Stage 8.4). This table serves two purposes:
///
/// 1. **Idempotency guard**: The unique index on `(entityId, deviceId, id)`
///    prevents double-application of retried pushes.
/// 2. **Watermark tracking**: The `opSeq` column tracks the highest applied
///    server sequence number, enabling efficient pull-since queries.
///
/// This is separate from `AuditLogs` (which records LOCAL mutations).
/// `SyncOperations` records INBOUND remote mutations.
@TableIndex(
  name: 'idx_sync_ops_idempotency',
  columns: {#entityId, #deviceId, #id},
  unique: true,
)
@TableIndex(name: 'idx_sync_ops_seq', columns: {#opSeq})
@TableIndex(
  name: 'idx_sync_ops_entity',
  columns: {#entityType, #entityId},
)
class SyncOperations extends Table {
  /// UUID v4 — same as the AuditLog id on the originating device.
  TextColumn get id => text()();

  /// Type of entity modified ('ledger', 'contact', 'transaction').
  TextColumn get entityType => text()();

  /// UUID of the target entity.
  TextColumn get entityId => text()();

  /// The mutation type ('CREATE', 'UPDATE', 'DELETE').
  TextColumn get action => text()();

  /// JSON map of changed fields → new values. Nullable for CREATE/DELETE.
  TextColumn get fieldDeltas => text().nullable()();

  /// Identifier of the device that originated this operation.
  TextColumn get deviceId => text()();

  /// Workspace role of the user ('owner', 'editor').
  TextColumn get role => text()();

  /// Device-local UTC timestamp when the op was created.
  DateTimeColumn get localTimestamp => dateTime()();

  /// Server-assigned UTC timestamp (ordering authority).
  DateTimeColumn get serverUpdatedAt => dateTime()();

  /// Server-assigned monotonic sequence number.
  IntColumn get opSeq => integer()();

  /// UTC timestamp when this op was applied locally.
  DateTimeColumn get appliedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
