import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/premium_upsell_policy.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapSeatCapExceededFailure', () {
    test('maps 409 seat_cap_exceeded', () {
      const error = ServerException(
        'Seat cap exceeded',
        statusCode: 409,
        errorCode: 'seat_cap_exceeded',
      );

      final failure = mapSeatCapExceededFailure(error);

      expect(failure, isA<SeatCapExceededFailure>());
      expect(failure?.maxWorkers, AppConstants.maxWorkerSeats);
      expect(failure?.code, 'seat_cap_exceeded');
    });

    test('returns null for 429 rate_limited', () {
      const error = ServerException(
        'Rate limited',
        statusCode: 429,
        errorCode: 'rate_limited',
      );

      expect(mapSeatCapExceededFailure(error), isNull);
    });
  });

  group('PremiumUpsellPolicy', () {
    test('seat cap is not an upsell feature key', () {
      expect(
        PremiumUpsellPolicy.showsPremiumUpsell(
          const LimitExceededFailure(
            'Team full',
            featureKey: 'workerSeats',
            currentCount: 2,
            maxAllowed: 2,
          ),
        ),
        isFalse,
      );
    });

    test('multiDeviceSync shows upsell', () {
      expect(
        PremiumUpsellPolicy.showsPremiumUpsell(
          const LimitExceededFailure(
            'Pro+ required',
            featureKey: AppConstants.featureMultiDeviceSync,
            currentCount: 0,
            maxAllowed: 0,
          ),
        ),
        isTrue,
      );
    });
  });
}
