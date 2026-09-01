/// Outcome classification for a sync/merge operation.
enum SyncResultType {
  /// All operations merged successfully with no conflicts.
  success,

  /// Some operations merged but conflicts were surfaced.
  partial,

  /// The merge operation failed entirely.
  failed,

  /// Pro+ entitled but no sync activity yet (never pushed/pulled).
  idle,

  /// The merge engine is dormant (user lacks Pro+ entitlement).
  dormant,
}
