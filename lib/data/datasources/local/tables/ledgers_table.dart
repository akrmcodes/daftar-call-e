import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:drift/drift.dart';

/// Drift table definition for the `ledgers` SQLite table.
///
/// Ledgers are the top-level organizational unit grouping contacts.
/// Maps 1:1 to the domain `Ledger` entity.
///
/// Columns match the domain entity fields:
/// - `id`: UUID v4 text primary key.
/// - `name`: User-defined ledger name.
/// - `type`: `LedgerType` enum stored as text.
/// - `icon`: Icon identifier string.
/// - `color`: Hex color string.
/// - `sortOrder`: Manual ordering position.
/// - `createdAt`, `updatedAt`: UTC timestamps.
/// - `isDeleted`: Soft-delete flag (default false).
/// - `syncVersion`: Sync conflict resolution counter (default 0).
@TableIndex(name: 'idx_ledgers_deleted', columns: {#isDeleted})
@TableIndex(name: 'idx_ledgers_archived', columns: {#isArchived})
@TableIndex(name: 'idx_ledgers_user_archived', columns: {#isUserArchived})
@TableIndex(name: 'idx_ledgers_sort', columns: {#sortOrder})
@TableIndex(
  name: 'idx_ledgers_active_list',
  columns: {#isDeleted, #isArchived, #isUserArchived, #sortOrder, #name},
)
class Ledgers extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// User-defined ledger name.
  TextColumn get name => text()();

  /// Business category stored as text enum.
  TextColumn get type => textEnum<LedgerType>()();

  /// Icon identifier for UI display.
  TextColumn get icon => text()();

  /// Hex color string for visual differentiation.
  TextColumn get color => text()();

  /// Manual ordering position in the ledger list.
  IntColumn get sortOrder => integer()();

  /// UTC timestamp of creation.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag. True = logically deleted.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Import/archive-first rows excluded from live workspace until promoted.
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get isUserArchived =>
      boolean().withDefault(const Constant(false))();

  TextColumn get carryForwardTargetLedgerId =>
      text().nullable().references(Ledgers, #id)();

  /// Monotonically increasing version for sync conflict resolution.
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
