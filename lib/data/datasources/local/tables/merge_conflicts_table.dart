import 'package:drift/drift.dart';

/// Drift table definition for the `merge_conflicts` SQLite table.
///
/// Stores detected merge conflicts that require user attention.
/// Created by the Merge Engine (Stage 8.4) when an ambiguous or
/// un-auto-resolvable conflict is detected during op-log replay.
///
/// Conflicts are surfaced to the Smart Merge UI (Stage 9) and the
/// Sync Report screen for manual resolution.
@TableIndex(
  name: 'idx_merge_conflicts_entity',
  columns: {#entityType, #entityId},
)
@TableIndex(
  name: 'idx_merge_conflicts_unresolved',
  columns: {#isResolved},
)
class MergeConflicts extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Type of the conflicting entity ('ledger', 'contact', 'transaction').
  TextColumn get entityType => text()();

  /// UUID of the conflicting entity.
  TextColumn get entityId => text()();

  /// Classification: 'deleteVsEdit', 'concurrentCreate', 'ambiguous'.
  TextColumn get conflictType => text()();

  /// JSON snapshot of the local entity state at conflict time.
  TextColumn get localSnapshot => text()();

  /// JSON snapshot of the remote entity state at conflict time.
  TextColumn get remoteSnapshot => text()();

  /// UTC timestamp when the conflict was detected.
  DateTimeColumn get detectedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp when the conflict was resolved. Null if unresolved.
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  /// Whether this conflict has been resolved.
  BoolColumn get isResolved =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
