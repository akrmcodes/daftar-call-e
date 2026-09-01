/// Thrown when a Google Drive backup operation fails after a successful HTTP
/// round-trip with an error payload, or when the error is mapped from this
/// data source for the repository layer to convert into domain failures.
class GoogleDriveBackupException implements Exception {
  /// Creates a [GoogleDriveBackupException].
  GoogleDriveBackupException(
    this.message, {
    this.status,
    this.reason,
    this.cause,
  });

  /// Human-readable message (API message when available).
  final String message;

  /// HTTP status when the failure came from a Drive `DetailedApiRequestError`.
  final int? status;

  /// First error `reason` from the Drive JSON error payload (e.g.
  /// `storageQuotaExceeded`), when available.
  final String? reason;

  /// Original error object, if any.
  final Object? cause;

  @override
  String toString() =>
      'GoogleDriveBackupException(status: $status, reason: $reason, '
      'message: $message)';
}
