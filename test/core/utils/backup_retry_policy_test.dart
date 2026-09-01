import 'dart:async';
import 'dart:math' as math;

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/backup_retry_policy.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  tearDown(() {
    BackupRetryPolicy.debugRandom = null;
  });

  group('BackupRetryPolicy', () {
    test('maxAttempts is 5 per roadmap', () {
      expect(BackupRetryPolicy.maxAttempts, 5);
      expect(BackupRetryPolicy.baseDelay, const Duration(seconds: 2));
      expect(BackupRetryPolicy.maxDelay, const Duration(minutes: 5));
    });

    test('backoffDelayForFailureAttempt respects jitter bounds per attempt', () {
      const baseMs = 2000;
      const maxMs = 300000;

      for (var attempt = 1; attempt <= BackupRetryPolicy.maxAttempts; attempt++) {
        final nominalMs = (baseMs * (1 << (attempt - 1))).clamp(0, maxMs);
        final delay =
            BackupRetryPolicy.backoffDelayForFailureAttempt(attempt);

        expect(
          delay.inMilliseconds,
          greaterThanOrEqualTo((nominalMs * 0.75).round()),
        );
        expect(
          delay.inMilliseconds,
          lessThanOrEqualTo(maxMs),
        );
        expect(
          delay.inMilliseconds,
          lessThanOrEqualTo((nominalMs * 1.25).round() + 1),
        );
      }
    });

    test('backoffDelayForFailureAttempt grows with attempt count', () {
      final first = BackupRetryPolicy.backoffDelayForFailureAttempt(1);
      final second = BackupRetryPolicy.backoffDelayForFailureAttempt(2);

      expect(first.inMilliseconds, greaterThanOrEqualTo(1500));
      expect(first.inMilliseconds, lessThanOrEqualTo(2500));
      expect(second.inMilliseconds, greaterThan(first.inMilliseconds ~/ 2));
      expect(second.inMilliseconds, lessThanOrEqualTo(300000));
    });

    test('backoffDelayForFailureAttempt caps at five minutes', () {
      final delay =
          BackupRetryPolicy.backoffDelayForFailureAttempt(5);

      expect(delay.inMilliseconds, lessThanOrEqualTo(300000));
    });

    test('execute returns Right on first success', () async {
      final result = await BackupRetryPolicy.execute(() async => 42);

      expect(result.getOrElse((_) => -1), 42);
    });

    test('nominal backoff sequence with jitter factor 1.0', () {
      BackupRetryPolicy.debugRandom = _FixedRandom(0.5);

      final delays = [
        for (var attempt = 1; attempt <= BackupRetryPolicy.maxAttempts; attempt++)
          BackupRetryPolicy.backoffDelayForFailureAttempt(attempt)
              .inMilliseconds,
      ];

      expect(delays, [2000, 4000, 8000, 16000, 32000]);
    });

    test('max jitter factor 1.25 scales nominal delays upward', () {
      BackupRetryPolicy.debugRandom = _FixedRandom(1);

      final delays = [
        for (var attempt = 1; attempt <= BackupRetryPolicy.maxAttempts; attempt++)
          BackupRetryPolicy.backoffDelayForFailureAttempt(attempt)
              .inMilliseconds,
      ];

      expect(delays, [2500, 5000, 10000, 20000, 40000]);
    });

    test('jitter lower and upper bounds with fixed random', () {
      BackupRetryPolicy.debugRandom = _FixedRandom(0);
      expect(
        BackupRetryPolicy.backoffDelayForFailureAttempt(1).inMilliseconds,
        (2000 * 0.75).round(),
      );

      BackupRetryPolicy.debugRandom = _FixedRandom(1);
      expect(
        BackupRetryPolicy.backoffDelayForFailureAttempt(1).inMilliseconds,
        (2000 * 1.25).round(),
      );
    });

    test('exponential curve holds with fixed jitter factor 1.0', () {
      BackupRetryPolicy.debugRandom = _FixedRandom(0.5);

      final delays = [
        for (var attempt = 1; attempt <= 4; attempt++)
          BackupRetryPolicy.backoffDelayForFailureAttempt(attempt)
              .inMilliseconds,
      ];

      for (var i = 0; i < delays.length - 1; i++) {
        expect(delays[i + 1], greaterThanOrEqualTo(delays[i]));
      }
    });

    test('execute retries until success on fifth attempt', () async {
      BackupRetryPolicy.debugRandom = _FixedRandom(0);
      var calls = 0;

      final result = await BackupRetryPolicy.execute(() async {
        calls++;
        if (calls < 5) {
          throw Exception('transient');
        }
        return 'ok';
      });

      expect(result, const Right<String, String>('ok'));
      expect(calls, 5);
    });

    test('execute returns backup_retry_exhausted after five failures', () async {
      BackupRetryPolicy.debugRandom = _FixedRandom(0);
      var calls = 0;

      final result = await BackupRetryPolicy.execute(() async {
        calls++;
        throw Exception('persistent');
      });

      expect(calls, 5);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
          expect(failure.code, 'backup_retry_exhausted');
        },
        (_) => fail('Expected Left'),
      );
    });

    test('execute elapses four backoff delays but not a fifth on exhaustion', () {
      fakeAsync((async) {
        BackupRetryPolicy.debugRandom = _FixedRandom(0);
        var calls = 0;
        Either<Failure, String>? result;

        unawaited(
          BackupRetryPolicy.execute(() async {
            calls++;
            throw Exception('persistent');
          }).then((value) {
            result = value;
          }),
        );

        async
          ..elapse(const Duration(milliseconds: 22500))
          ..flushMicrotasks();

        expect(calls, 5);
        expect(result?.isLeft(), isTrue);
        expect(async.elapsed.inMilliseconds, 22500);
      });
    });
  });
}

/// Returns a constant value in `[0, 1)` mapped to jitter factor `0.75 + v * 0.5`.
class _FixedRandom implements math.Random {
  _FixedRandom(this._value);

  final double _value;

  @override
  bool nextBool() => _value >= 0.5;

  @override
  double nextDouble() => _value;

  @override
  int nextInt(int max) => (_value * max).floor();
}
