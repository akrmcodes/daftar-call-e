import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockActivationRepository extends Mock implements ActivationRepository {}

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

void main() {
  late MockActivationRepository activation;
  late MockSyncAuthBridgeRepository syncAuthBridge;
  late IsMultiDeviceSyncUnlockedUseCase sut;

  setUp(() {
    activation = MockActivationRepository();
    syncAuthBridge = MockSyncAuthBridgeRepository();
    sut = IsMultiDeviceSyncUnlockedUseCase(
      activationRepository: activation,
      syncAuthBridgeRepository: syncAuthBridge,
    );
  });

  group('IsMultiDeviceSyncUnlockedUseCase', () {
    test('contest kill-switch is on for this build', () {
      expect(AppConstants.kContestDisableMultiDeviceSync, isTrue);
    });

    test('always returns false when contest kill-switch is on', () async {
      final result = await sut.call();

      expect(result, isFalse);
      verifyNever(() => activation.isFeatureUnlocked(FeatureFlag.multiDeviceSync));
      verifyNever(() => syncAuthBridge.readLastKnownMembership());
    });
  });
}
