// Data-layer exceptions that are caught and mapped to `Failure` subtypes
// in repository implementations.
//
// These exceptions MUST NEVER escape the data layer. Every repository
// implementation catches them and returns the corresponding `Left(Failure)`.

/// Thrown by local data sources when a Drift operation fails.
///
/// Maps to `DatabaseFailure` in repository implementations.
class DatabaseException implements Exception {
  /// Creates a [DatabaseException] with the given [message].
  const DatabaseException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'DatabaseException: $message';
}

/// Thrown when server or network requests fail.
///
/// Maps to `NetworkFailure` in repository implementations.
class ServerException implements Exception {
  /// Creates a [ServerException] with the given [message] and optional
  /// [statusCode], [errorCode], and [retryAfterSeconds].
  const ServerException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.retryAfterSeconds,
  });

  /// The error message describing what went wrong.
  final String message;

  /// Optional HTTP status code from the failed request.
  final int? statusCode;

  /// Optional machine-readable error code from the server body.
  final String? errorCode;

  /// Optional `Retry-After` hint from a `429 rate_limited` response body.
  final int? retryAfterSeconds;

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown when file system, secure storage, or encryption operations fail.
///
/// Maps to `StorageFailure` in repository implementations.
class StorageException implements Exception {
  /// Creates a [StorageException] with the given [message].
  const StorageException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'StorageException: $message';
}

/// Thrown when authentication operations fail (PIN, biometric, OTP, token).
///
/// Maps to `AuthFailure` in repository implementations.
class AuthException implements Exception {
  /// Creates an [AuthException] with the given [message].
  const AuthException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when device or monthly sync caps are exceeded.
class SyncCapExceededException implements Exception {
  /// Creates the exception.
  const SyncCapExceededException({required this.code});

  /// Machine-readable cap code from the Edge Function.
  final String code;
}
