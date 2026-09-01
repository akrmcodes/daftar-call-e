/// Drive backup outcome for a close-the-day ritual.
enum ClosingBackupStatus {
  /// Encrypted snapshot uploaded to Drive.
  uploaded,

  /// Snapshot queued for later upload (offline / in-flight).
  queued,

  /// Upload failed and could not be queued.
  failed,

  /// Merchant is not signed in to Google Drive.
  skippedUnsigned,

  /// Signed in but Drive offline grant / scopes were not completed.
  grantRequired,
}
