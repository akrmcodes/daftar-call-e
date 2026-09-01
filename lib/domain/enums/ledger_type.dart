/// Categorizes ledgers by their business purpose.
///
/// - [customers]: Tracks debts owed by customers to the merchant.
/// - [suppliers]: Tracks debts the merchant owes to suppliers.
/// - [personal]: Personal lending/borrowing, not business-related.
/// - [custom]: User-defined category for any other purpose.
enum LedgerType {
  /// Customers who owe money to the merchant.
  customers,

  /// Suppliers to whom the merchant owes money.
  suppliers,

  /// Personal debts outside of business.
  personal,

  /// User-defined custom ledger category.
  custom,
}
