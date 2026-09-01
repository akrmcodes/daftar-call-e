/// Progress checkpoints while the close-the-day ritual runs.
enum ClosingRitualStep {
  /// Drift `localDay` snapshot is ready.
  summary,

  /// Drive upload finished, queued, or skipped.
  backup,

  /// Collections shortlist is ready.
  shortlist,
}
