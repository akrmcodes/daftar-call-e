/// Local agent outbox queue status (thin queue; processors land in Stage 5).
enum AgentOutboxStatus {
  /// Waiting to be processed.
  queued,

  /// A previous attempt failed; waiting until `nextRetryAt`.
  retrying,

  /// Permanently failed.
  failed,

  /// Processed successfully.
  done,
}
