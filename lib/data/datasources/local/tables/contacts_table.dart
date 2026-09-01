import 'package:daftar/data/datasources/local/tables/ledgers_table.dart';
import 'package:drift/drift.dart';

/// Drift table definition for the `contacts` SQLite table.
///
/// Each contact belongs to exactly one ledger via [ledgerId] FK.
/// Maps 1:1 to the domain `Contact` entity.
///
/// Supports:
/// - Soft deletion via [isDeleted].
/// - Sync conflict resolution via [syncVersion].
/// - Optional credit limit tracking.
/// - Optional phone number for WhatsApp integration.
@TableIndex(name: 'idx_contacts_ledger', columns: {#ledgerId})
@TableIndex(name: 'idx_contacts_name', columns: {#name})
@TableIndex(name: 'idx_contacts_deleted', columns: {#isDeleted})
@TableIndex(name: 'idx_contacts_archived', columns: {#isArchived})
@TableIndex(name: 'idx_contacts_email', columns: {#email})
@TableIndex(
  name: 'idx_contacts_ledger_active_name',
  columns: {#ledgerId, #isDeleted, #isArchived, #name},
)
class Contacts extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// FK to the parent [Ledgers] table.
  TextColumn get ledgerId =>
      text().references(Ledgers, #id)();

  /// Contact's display name (Arabic names common).
  TextColumn get name => text()();

  /// Optional phone number for WhatsApp/call integration.
  TextColumn get phone => text().nullable()();

  /// Optional email for Collections SMTP (Appendix C.2 / J.7).
  TextColumn get email => text().nullable()();

  /// Optional free-text notes about the contact.
  TextColumn get notes => text().nullable()();

  /// Optional maximum debt threshold in smallest currency unit.
  IntColumn get creditLimit => integer().nullable()();

  /// Currency code for the credit limit (e.g., 'YER').
  TextColumn get creditCurrency => text().nullable()();

  /// Hex color string for the contact's avatar.
  TextColumn get avatarColor => text()();

  /// UTC timestamp of creation.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Archive-first import row; not counted in live workspace until promoted.
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  /// Version counter for sync conflict resolution.
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
