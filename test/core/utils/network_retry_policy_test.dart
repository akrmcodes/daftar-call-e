import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/network_retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  setUp(() {
    NetworkRetryPolicy.debugDelay = (_) async {};
  });

  tearDown(() {
    NetworkRetryPolicy.debugDelay = null;
    NetworkRetryPolicy.debugRandom = null;
  });

  group('NetworkRetryPolicy', () {
    test('returns Right on first success', () async {
      var calls = 0;
      final result = await NetworkRetryPolicy.execute(() async {
        calls++;
        return 42;
      });
      expect(result, const Right<Failure, int>(42));
      expect(calls, 1);
    });

    test('retries transient failures then succeeds', () async {
      var calls = 0;
      final result = await NetworkRetryPolicy.execute(() async {
        calls++;
        if (calls < 3) {
          throw Exception('transient');
        }
        return 'ok';
      });
      expect(result, const Right<Failure, String>('ok'));
      expect(calls, 3);
    });

    test('returns Left after exhausting attempts', () async {
      final result = await NetworkRetryPolicy.execute(() async {
        throw Exception('always fails');
      });
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NetworkFailure>()),
        (_) => fail('expected failure'),
      );
    });

    test('does not retry 4xx ServerException', () async {
      var calls = 0;
      final result = await NetworkRetryPolicy.execute(() async {
        calls++;
        throw const ServerException(
          'device cap',
          statusCode: 409,
          errorCode: 'device_cap_exceeded',
        );
      });
      expect(calls, 1);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'device_cap_exceeded'),
        (_) => fail('expected failure'),
      );
    });
  });
}
