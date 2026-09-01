/// Statement-PDF attach policy stored for Collections Desk (Stage 4.2).
enum ClosingPdfPolicy {
  /// Do not attach statements.
  none,

  /// Attach for firm-tone or age ≥ 30 days in the reminder set.
  selective,

  /// Attach for every contact in the reminder set.
  allInSet,

  /// Attach for ranked Top 5 of the send set (v2.8). If N < 5, all N.
  rankedTop5,
}
