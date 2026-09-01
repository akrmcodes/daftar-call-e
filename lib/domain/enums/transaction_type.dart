/// Represents the direction of a financial transaction.
///
/// - [debt]: Money owed (عليه) — increases the contact's balance.
/// - [payment]: Money paid (له) — decreases the contact's balance.
enum TransactionType {
  /// A debt entry — the contact owes more to the merchant.
  debt,

  /// A payment entry — the contact has paid toward their debt.
  payment,
}
