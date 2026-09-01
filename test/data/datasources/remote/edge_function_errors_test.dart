import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapRateLimitedFailure', () {
    test('maps 429 rate_limited with retry_after', () {
      const error = ServerException(
        'Rate limited',
        statusCode: 429,
        errorCode: 'rate_limited',
        retryAfterSeconds: 3600,
      );

      final failure = mapRateLimitedFailure(error);

      expect(failure, isA<RateLimitedFailure>());
      expect(failure?.retryAfterSeconds, 3600);
      expect(failure?.code, 'rate_limited');
    });

    test('returns null for non-429 errors', () {
      const error = ServerException(
        'Seat cap exceeded',
        statusCode: 409,
        errorCode: 'seat_cap_exceeded',
      );

      expect(mapRateLimitedFailure(error), isNull);
    });

    test('returns null for 429 with different error code', () {
      const error = ServerException(
        'Other limit',
        statusCode: 429,
        errorCode: 'other_limit',
      );

      expect(mapRateLimitedFailure(error), isNull);
    });
  });
}
