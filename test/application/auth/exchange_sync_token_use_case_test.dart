import 'package:daftar/application/auth/exchange_sync_token_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

void main() {
  late MockSyncAuthBridgeRepository repository;
  late ExchangeSyncTokenUseCase sut;

  setUp(() {
    repository = MockSyncAuthBridgeRepository();
    sut = ExchangeSyncTokenUseCase(repository);
  });

  group('ExchangeSyncTokenUseCase', () {
    test('contest kill-switch is on for this build', () {
      expect(AppConstants.kContestDisableMultiDeviceSync, isTrue);
    });

    test('ensureValid returns AuthFailure without bridge call when quarantined',
        () async {
      final result = await sut.ensureValid();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'contest_sync_quarantined');
        },
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(
        () => repository.ensureValid(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });

    test('exchange returns AuthFailure without bridge call when quarantined',
        () async {
      final result = await sut.exchange();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'contest_sync_quarantined');
        },
        (_) => fail('expected contest quarantine failure'),
      );
      verifyNever(
        () => repository.exchange(
          allowInteractive: any(named: 'allowInteractive'),
        ),
      );
    });
  });
}
