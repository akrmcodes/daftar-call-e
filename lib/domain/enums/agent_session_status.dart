/// Lifecycle status of an agent session.
enum AgentSessionStatus {
  /// Session is in progress.
  active,

  /// Session finished successfully.
  completed,

  /// Session was cancelled without completing.
  cancelled,
}
