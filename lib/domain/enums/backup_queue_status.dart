/// Persisted state for a row in the Drive backup upload queue.
enum BackupQueueStatus {
  /// Waiting for first attempt or scheduler pickup.
  queued,

  /// An upload attempt is in progress or was just attempted.
  retrying,

  /// Google auth is missing; user must sign in again.
  needsReauth,

  /// Gave up after repeated failures (or non-retryable error).
  failed,
}
