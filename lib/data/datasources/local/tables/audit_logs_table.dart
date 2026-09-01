import 'package:drift/drift.dart';

/// Drift table definition for the `audit_logs` SQLite table.
///
/// Immutable, append-only log of all data modification events.
/// Maps 1:1 to the domain `AuditLog` entity.
///
/// Every CREATE, UPDATE, and DELETE operation on core entities
/// appends an entry to this table. Entries are never modified or deleted.
///
/// No sync fields — audit logs are the source of truth for sync replay.
@TableIndex(
  name: 'idx_audit_entity',
  columns: {#entityType, #entityId},
)
@TableIndex(name: 'idx_audit_timestamp', columns: {#timestamp})
@TableIndex(
  name: 'idx_audit_entity_timestamp',
  columns: {#entityType, #entityId, #timestamp},
)
class AuditLogs extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Type of entity modified (e.g., 'ledger', 'contact', 'transaction').
  TextColumn get entityType => text()();

  /// UUID of the modified entity.
  TextColumn get entityId => text()();

  /// The operation performed ('CREATE', 'UPDATE', 'DELETE').
  TextColumn get action => text()();

  /// Optional JSON string containing the changed fields/values.
  TextColumn get payload => text().nullable()();

  /// UTC timestamp of the operation.
  DateTimeColumn get timestamp =>
      dateTime().withDefault(currentDateAndTime)();

  /// Identifier for the device that performed the operation.
  TextColumn get deviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
