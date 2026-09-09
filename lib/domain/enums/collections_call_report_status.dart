/// Per-contact call row on the sealed close-the-day report.
///
/// Matches roadmap §3.11. Never `delivered` or `paid`.
enum CollectionsCallReportStatus {
  /// Queued for dial.
  planned,

  /// CALL-E reports ringing.
  ringing,

  /// Terminal success (promise captured or call ended).
  completed,

  /// Terminal failure or needs human.
  failed,

  /// Call-set member the merchant did not dial this close.
  skipped,

  /// Unsupported region (including YE) — never posted to CALL-E.
  callUnavailable,
}
