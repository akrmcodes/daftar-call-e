import 'package:drift/drift.dart';

/// Drift table definition for the `contact_balances` SQLite table.
///
/// Denormalized balance records providing O(1) balance lookups instead
/// of aggregating from raw transactions. Updated atomically within
/// the same Drift transaction that creates/modifies/deletes a transaction.
///
/// Maps 1:1 to the domain `ContactBalance` entity.
///
/// Uses composite primary key (contactId, currencyCode) — each contact
/// can have one balance record per currency.
///
/// No sync fields — this is derived data recalculated from transactions.
class ContactBalances extends Table {
  /// FK to the contact. Part of composite PK.
  TextColumn get contactId => text()();

  /// ISO 4217 currency code. Part of composite PK.
  TextColumn get currencyCode => text()();

  /// Sum of all debt transaction amounts (smallest currency unit).
  IntColumn get totalDebt => integer().withDefault(const Constant(0))();

  /// Sum of all payment transaction amounts (smallest currency unit).
  IntColumn get totalPayment => integer().withDefault(const Constant(0))();

  /// Net balance: totalPayment - totalDebt.
  /// Positive = payments exceed debt.
  IntColumn get netBalance => integer().withDefault(const Constant(0))();

  /// UTC timestamp when this balance was last recalculated.
  DateTimeColumn get lastUpdatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {contactId, currencyCode};
}
