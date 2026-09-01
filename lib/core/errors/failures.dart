import 'package:daftar/core/constants/app_constants.dart';

/// Sealed hierarchy of domain-level failure types.
///
/// All error conditions in the Daftar domain are represented as [Failure]
/// subtypes. Raw exceptions MUST NEVER leave the data layer — they are
/// caught and mapped to the appropriate [Failure] before crossing the
/// repository boundary.
///
/// Use exhaustive `switch` on [Failure] for pattern matching in the
/// presentation layer.
sealed class Failure {
  /// Creates a [Failure] with a [message] and optional [code].
  const Failure(this.message, {this.code});

  /// Human-readable, localizable error message.
  final String message;

  /// Optional machine-readable error code for programmatic handling.
  final String? code;
}

/// A failure originating from the local Drift database layer.
///
/// Triggered by: SQL constraint violations, I/O errors, migration failures,
/// or any `DriftWrappedException` caught in repository implementations.
final class DatabaseFailure extends Failure {
  /// Creates a [DatabaseFailure] with the given [message].
  const DatabaseFailure(super.message, {super.code});
}

/// A failure caused by invalid user input or broken business rules.
///
/// Triggered by: empty names, duplicate entries, malformed phone numbers,
/// invalid amounts, or any precondition violation in use cases.
final class ValidationFailure extends Failure {
  /// Creates a [ValidationFailure] with the given [message].
  const ValidationFailure(super.message, {super.code});
}

/// A failure caused by an invalid transaction amount.
///
/// Triggered by: zero or negative transaction amounts supplied to the
/// transaction creation use case.
final class InvalidAmountFailure extends Failure {
  /// Creates an [InvalidAmountFailure] with the offending [amount].
  const InvalidAmountFailure(
    super.message, {
    required this.amount,
    super.code,
  });

  /// The invalid amount supplied by the caller.
  final int amount;

  @override
  String toString() =>
      'InvalidAmountFailure(message: $message, amount: $amount)';
}

/// A failure caused by network connectivity or remote service issues.
///
/// Triggered by: no internet, DNS resolution failure, HTTP errors,
/// Supabase API errors, or request timeouts.
final class NetworkFailure extends Failure {
  /// Creates a [NetworkFailure] with the given [message].
  const NetworkFailure(super.message, {super.code});
}

/// Google Drive account storage is full — uploads cannot proceed until the
/// user frees space. This is **not** a transient error: callers must not
/// apply exponential backoff or automatic retry loops.
final class QuotaExceededFailure extends Failure {
  /// Creates a [QuotaExceededFailure] with the given [message].
  const QuotaExceededFailure(super.message, {super.code});
}

/// A failure related to file system or secure storage operations.
///
/// Triggered by: disk full, file not found, permission denied,
/// encryption/decryption errors, or backup file corruption.
final class StorageFailure extends Failure {
  /// Creates a [StorageFailure] with the given [message].
  const StorageFailure(super.message, {super.code});
}

/// Device free storage is below the minimum required for safe heavy I/O.
///
/// Returned before local backup, restore, Drive snapshot, or PDF export
/// when free space is below the app minimum (50 MB by default).
final class StorageFullFailure extends Failure {
  /// Creates a [StorageFullFailure] with the required free-space floor.
  const StorageFullFailure({
    String message = 'Device storage is critically low.',
    this.minMegabytesRequired = 50,
    String? code = 'device_storage_full',
  }) : super(message, code: code);

  /// Minimum free megabytes that must be available to proceed.
  final int minMegabytesRequired;
}

/// A failure related to authentication or authorization.
///
/// Triggered by: invalid PIN, biometric failure, expired auth token,
/// OTP verification failure, or unauthorized access attempts.
final class AuthFailure extends Failure {
  /// Creates an [AuthFailure] with the given [message].
  const AuthFailure(super.message, {super.code});

  /// Google account is not signed in; interactive sign-in is required.
  static const AuthFailure notSignedIn = AuthFailure(
    'Sign in with Google to use Google Drive backup.',
    code: 'google_not_signed_in',
  );
}

/// The caller is authenticated but not allowed to perform this action.
///
/// Distinct from [AuthFailure]: the credential is valid, so re-authenticating
/// or refreshing the token changes nothing. Retrying is equally pointless —
/// only a role change on the server can lift it.
final class ForbiddenFailure extends Failure {
  /// Creates a [ForbiddenFailure].
  const ForbiddenFailure(super.message, {super.code = 'forbidden'});
}

/// A failure when an invite-class endpoint returns HTTP 429 rate limiting.
///
/// Distinct from [LimitExceededFailure] — no premium upsell; user should retry
/// later (optionally guided by [retryAfterSeconds]).
final class RateLimitedFailure extends Failure {
  /// Creates a [RateLimitedFailure] with optional retry guidance.
  const RateLimitedFailure(
    super.message, {
    this.retryAfterSeconds,
    super.code = 'rate_limited',
  });

  /// Seconds until the client may retry, when provided by the server.
  final int? retryAfterSeconds;
}

/// Workspace worker seat cap reached (Owner + up to 2 workers on Pro+).
///
/// Not a monetization gate — upgrading does not raise this cap.
final class SeatCapExceededFailure extends Failure {
  /// Creates a [SeatCapExceededFailure] for a full team roster.
  const SeatCapExceededFailure(
    super.message, {
    this.maxWorkers = AppConstants.maxWorkerSeats,
    super.code = 'seat_cap_exceeded',
  });

  /// Maximum worker seats allowed (excluding owner).
  final int maxWorkers;
}

/// A failure indicating a free-tier resource limit has been exceeded.
///
/// Triggered when a non-premium user attempts to exceed:
/// - 1 ledger ([featureKey] = 'unlimitedLedgers')
/// - 50 contacts ([featureKey] = 'unlimitedContacts')
/// - 500 transactions ([featureKey] = 'unlimitedTransactions')
///
/// The presentation layer uses [featureKey], [currentCount], and
/// [maxAllowed] to display contextual upgrade prompts.
final class LimitExceededFailure extends Failure {
  /// Creates a [LimitExceededFailure] with the given parameters.
  const LimitExceededFailure(
    super.message, {
    required this.featureKey,
    required this.currentCount,
    required this.maxAllowed,
    super.code,
  });

  /// The premium feature key required to bypass this limit.
  ///
  /// Maps to activation tier feature flags:
  /// `unlimitedLedgers`, `unlimitedContacts`, `unlimitedTransactions`,
  /// `cloudBackup`, `csvImport`, `creditLimits`, `whatsappAutomation`.
  final String featureKey;

  /// The current count of the resource at the time of the check.
  final int currentCount;

  /// The maximum allowed count for the user's current tier.
  final int maxAllowed;

  @override
  String toString() =>
      'LimitExceededFailure(message: $message, featureKey: $featureKey, '
      'currentCount: $currentCount, maxAllowed: $maxAllowed)';
}

/// A failure indicating the transaction free-tier limit has been reached.
///
/// Triggered when a free-tier user attempts to create transaction number
/// 501 or higher.
final class FreeTierLimitReachedFailure extends Failure {
  /// Creates a [FreeTierLimitReachedFailure] with the given parameters.
  const FreeTierLimitReachedFailure(
    super.message, {
    required this.featureKey,
    required this.currentCount,
    required this.maxAllowed,
    super.code,
  });

  /// The premium feature key required to bypass this limit.
  final String featureKey;

  /// The current count of active transactions at the time of the check.
  final int currentCount;

  /// The maximum allowed count for the user's current tier.
  final int maxAllowed;

  @override
  String toString() =>
      'FreeTierLimitReachedFailure(message: $message, featureKey: '
      '$featureKey, currentCount: $currentCount, maxAllowed: $maxAllowed)';
}
