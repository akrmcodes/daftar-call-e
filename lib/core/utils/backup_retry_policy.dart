import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:daftar/core/errors/failures.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

/// Exponential backoff with symmetric ±25% jitter for transient backup errors.
///
/// Used for Google Drive and other network-bound backup steps. After the
/// `n`th failed attempt (1-based), the nominal backoff is
/// `min(baseMs * 2^(n-1), maxMs)` milliseconds. The actual sleep is that
/// nominal value multiplied by a uniform factor in `[0.75, 1.25]` (±25%),
/// then capped at [maxDelay] so wall-clock delay never exceeds five minutes.
class BackupRetryPolicy {
  BackupRetryPolicy._();

  static const int maxAttempts = 5;

  static const Duration baseDelay = Duration(seconds: 2);

  static const Duration maxDelay = Duration(minutes: 5);

  static final math.Random _random = math.Random();

  /// When set, overrides [math.Random] for deterministic unit tests.
  @visibleForTesting
  static math.Random? debugRandom;

  static math.Random get _effectiveRandom => debugRandom ?? _random;

  /// Runs [action] up to [maxAttempts] times with backoff between failures.
  ///
  /// On success, returns [Right] with the result. If every attempt throws
  /// [Exception], returns [Left] with [NetworkFailure].
  static Future<Either<Failure, T>> execute<T>(
    Future<T> Function() action,
  ) async {
    const baseMs = 2000;
    const maxMs = 300000;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await action();
        return Right(result);
      } on Exception catch (e, st) {
        if (attempt == maxAttempts) {
          developer.log(
            'BackupRetryPolicy: all $maxAttempts attempts failed: $e',
            name: 'BackupRetryPolicy',
            error: e,
            stackTrace: st,
          );
          return const Left(
            NetworkFailure(
              'Backup failed after multiple attempts. Please check your connection.',
              code: 'backup_retry_exhausted',
            ),
          );
        }

        final nominalMs = math.min(
          (baseMs * math.pow(2, attempt - 1)).round(),
          maxMs,
        );

        final jitterFactor = 0.75 + _effectiveRandom.nextDouble() * 0.5;
        var sleepMs = (nominalMs * jitterFactor).round();
        if (sleepMs > maxMs) {
          sleepMs = maxMs;
        }

        developer.log(
          'BackupRetryPolicy: attempt $attempt/$maxAttempts failed; '
          'sleeping ${sleepMs}ms before retry (nominal=${nominalMs}ms, '
          'jitterFactor=${jitterFactor.toStringAsFixed(3)}): $e',
          name: 'BackupRetryPolicy',
          stackTrace: st,
        );

        await Future<void>.delayed(Duration(milliseconds: sleepMs));
      }
    }

    throw StateError('BackupRetryPolicy.execute: unreachable');
  }

  /// Randomized backoff matching the retry policy after a failed attempt.
  ///
  /// [failedAttemptOneBased] is 1 for the first failure, then increments.
  static Duration backoffDelayForFailureAttempt(int failedAttemptOneBased) {
    assert(
      failedAttemptOneBased >= 1 && failedAttemptOneBased <= maxAttempts,
      'failedAttemptOneBased must be in [1, maxAttempts]',
    );
    const baseMs = 2000;
    const maxMs = 300000;
    final nominalMs = math.min(
      (baseMs * math.pow(2, failedAttemptOneBased - 1)).round(),
      maxMs,
    );
    final jitterFactor = 0.75 + _effectiveRandom.nextDouble() * 0.5;
    var sleepMs = (nominalMs * jitterFactor).round();
    if (sleepMs > maxMs) {
      sleepMs = maxMs;
    }
    return Duration(milliseconds: sleepMs);
  }
}
