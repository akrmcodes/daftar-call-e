import 'package:daftar/data/datasources/local/tables/contacts_table.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:drift/drift.dart';

/// Drift table definition for the `transactions` SQLite table.
///
/// Each transaction belongs to exactly one contact via [contactId] FK.
/// Maps 1:1 to the domain `Transaction` entity.
///
/// The [amount] is always stored as an integer in the smallest
/// currency unit (e.g., 1500 = 1500 YER or 1500 = 15.00 SAR). NEVER use real/double.
@TableIndex(name: 'idx_txn_contact', columns: {#contactId})
@TableIndex(name: 'idx_txn_date', columns: {#transactionDate})
@TableIndex(name: 'idx_txn_deleted', columns: {#isDeleted})
@TableIndex(name: 'idx_txn_archived', columns: {#isArchived})
@TableIndex(
  name: 'idx_txn_contact_list',
  columns: {#contactId, #isDeleted, #isArchived, #transactionDate, #createdAt},
)
@TableIndex(name: 'idx_txn_created_at', columns: {#createdAt})
class Transactions extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// FK to the parent [Contacts] table.
  TextColumn get contactId =>
      text().references(Contacts, #id)();

  /// Whether this is a debt (عليه) or payment (له).
  TextColumn get type => textEnum<TransactionType>()();

  /// Amount in the smallest currency unit. Always positive.
  IntColumn get amount => integer()();

  /// ISO 4217 currency code (e.g., 'YER').
  TextColumn get currency => text()();

  /// Optional free-text description.
  TextColumn get description => text().nullable()();

  /// Optional item name for smart autocomplete.
  TextColumn get itemName => text().nullable()();

  /// The date the transaction occurred (may differ from createdAt).
  DateTimeColumn get transactionDate => dateTime()();

  /// Optional file path to a receipt image or document.
  TextColumn get attachmentPath => text().nullable()();

  /// UTC timestamp of record creation.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false))();

  /// Archive-first import row; excluded from live counts until promoted.
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false))();

  /// Version counter for sync conflict resolution.
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
