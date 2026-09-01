/// User choice for CSV rows that resolve to contacts already stored in the ledger.
enum DuplicateResolutionStrategy {
  /// Attach imported transactions to the matched existing contact (no duplicate contact rows).
  merge,

  /// Omit transactions for rows that match an existing contact.
  skip,
}
