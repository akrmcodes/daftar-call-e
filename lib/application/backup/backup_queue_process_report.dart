/// Summary of side effects from one `ProcessBackupQueueUseCase` pass.
///
/// Used by presentation to update non-blocking Drive sync hints.
class BackupQueueProcessReport {
  /// Creates a report with the given flags.
  const BackupQueueProcessReport({
    this.sawNeedsReauth = false,
    this.sawQuotaExceeded = false,
    this.sawTransientNetworkFailure = false,
  });

  /// At least one row was marked `needsReauth` (silent auth insufficient).
  final bool sawNeedsReauth;

  /// Drive returned a storage quota error for at least one upload attempt.
  final bool sawQuotaExceeded;

  /// At least one failure was classified as a transient network fault
  /// and the row was scheduled for backoff retry.
  final bool sawTransientNetworkFailure;

  /// Merges this report with [other] using logical OR on each flag.
  BackupQueueProcessReport merge(BackupQueueProcessReport other) {
    return BackupQueueProcessReport(
      sawNeedsReauth: sawNeedsReauth || other.sawNeedsReauth,
      sawQuotaExceeded: sawQuotaExceeded || other.sawQuotaExceeded,
      sawTransientNetworkFailure:
          sawTransientNetworkFailure || other.sawTransientNetworkFailure,
    );
  }
}
