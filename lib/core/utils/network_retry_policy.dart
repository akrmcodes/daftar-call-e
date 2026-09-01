import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

/// Exponential backoff with symmetric ±25% jitter for transient network errors.
///
/// Shared by sync and backup flows. After the `n`th failed attempt (1-based),
/// nominal backoff is `min(baseMs * 2^(n-1), maxMs)` milliseconds.
class NetworkRetryPolicy {
  NetworkRetryPolicy._();

  static const int maxAttempts = 5;

  static const Duration baseDelay = Duration(seconds: 2);

  static const Duration maxDelay = Duration(minutes: 5);

  static final math.Random _random = math.Random();

  /// When set, overrides [math.Random] for deterministic unit tests.
  @visibleForTesting
  static math.Random? debugRandom;

  /// When set, replaces [Future.delayed] between retry attempts in tests.
  @visibleForTesting
  static Future<void> Function(Duration duration)? debugDelay;

  static math.Random get _effectiveRandom => debugRandom ?? _random;

  /// Runs [action] up to [maxAttempts] times with backoff between failures.
  static Future<Either<Failure, T>> execute<T>(
    Future<T> Function() action, {
    String exhaustedCode = 'sync_retry_exhausted',
    String exhaustedMessage =
        'Network operation failed after multiple attempts.',
  }) async {
    const baseMs = 2000;
    const maxMs = 300000;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await action();
        return Right(result);
      } on Exception catch (e, st) {
        final nonRetryable = _mapNonRetryableFailure(e);
        if (nonRetryable != null) {
          return Left(nonRetryable);
        }

        if (attempt == maxAttempts) {
          developer.log(
            'NetworkRetryPolicy: all $maxAttempts attempts failed: $e',
            name: 'NetworkRetryPolicy',
            error: e,
            stackTrace: st,
          );
          return Left(
            NetworkFailure(
              exhaustedMessage,
              code: exhaustedCode,
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
          'NetworkRetryPolicy: attempt $attempt/$maxAttempts failed; '
          'sleeping ${sleepMs}ms before retry: $e',
          name: 'NetworkRetryPolicy',
          stackTrace: st,
        );

        await (debugDelay ?? Future<void>.delayed)(
          Duration(milliseconds: sleepMs),
        );
      }
    }

    throw StateError('NetworkRetryPolicy.execute: unreachable');
  }

  static Failure? _mapNonRetryableFailure(Exception error) {
    if (error is SyncCapExceededException) {
      return NetworkFailure(
        'Sync limit exceeded',
        code: error.code,
      );
    }
    if (error is ServerException) {
      final code = error.errorCode;
      final status = error.statusCode;

      // A role rejection is deliberate and stable: the credential is valid,
      // so neither a retry nor a token re-exchange can change the answer.
      if (code == EdgeErrorCodes.forbidden || status == 403) {
        return ForbiddenFailure(error.message);
      }

      if (status != null && status >= 400 && status < 500) {
        return NetworkFailure(
          error.message,
          code: code ?? 'sync_client_error',
        );
      }
      if (code == EdgeErrorCodes.deviceRegistrationFailed ||
          code == EdgeErrorCodes.usageCounterWriteFailed) {
        return NetworkFailure(
          error.message,
          code: code,
        );
      }
    }
    return null;
  }

  /// Randomized backoff matching the retry policy after a failed attempt.
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
