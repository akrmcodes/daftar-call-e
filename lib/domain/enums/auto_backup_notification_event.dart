/// Auto-backup notification outcomes surfaced to the merchant.
enum AutoBackupNotificationEvent {
  /// Ongoing upload in progress.
  inProgress,

  /// Backup uploaded successfully.
  success,

  /// Transient failure; will retry when online.
  willRetry,

  /// Google session expired; interactive sign-in required.
  needsReauth,

  /// Google Drive storage quota exceeded.
  quotaExceeded,

  /// Device storage insufficient to create backup.
  storageFull,

  /// Unclassified backup failure.
  failed,
}
