/// Kind of an append-only day-journal row (AI audit, not money source of
/// truth).
enum DayJournalKind {
  /// A debt transaction was confirmed and committed.
  debtConfirmed,

  /// A payment transaction was confirmed and committed.
  paymentConfirmed,

  /// A contact was created via the confirm gate.
  contactCreated,

  /// A ledger was created via the confirm gate.
  ledgerCreated,

  /// A closing plan was confirmed.
  closingPlanConfirmed,

  /// The merchant skipped or cancelled a proposal.
  skipped,

  /// Free-form journal note (non-money).
  note,
}
