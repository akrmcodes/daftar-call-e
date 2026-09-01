import 'package:daftar/application/auth/ensure_pro_plus_sync_token_use_case.dart';
import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockIsMultiDeviceSyncUnlockedUseCase extends Mock
    implements IsMultiDeviceSyncUnlockedUseCase {}

class MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

void main() {
  late MockIsMultiDeviceSyncUnlockedUseCase unlocked;
  late MockSyncAuthBridgeRepository bridge;

  setUp(() {
    unlocked = MockIsMultiDeviceSyncUnlockedUseCase();
    bridge = MockSyncAuthBridgeRepository();
  });

  group('EnsureProPlusSyncTokenUseCase', () {
    test('returns null without bridge call when not unlocked', () async {
      when(() => unlocked.call()).thenAnswer((_) async => false);

      final useCase = EnsureProPlusSyncTokenUseCase(
        isMultiDeviceSyncUnlocked: unlocked,
        syncAuthBridgeRepository: bridge,
      );

      final result = await useCase();

      expect(result, const Right<Failure, SyncAuthCredentials?>(null));
      verifyNever(
        () => bridge.ensureValid(allowInteractive: any(named: 'allowInteractive')),
      );
    });

    test('exchanges token for worker when unlocked without personal Pro+',
        () async {
      when(() => unlocked.call()).thenAnswer((_) async => true);
      when(
        () => bridge.ensureValid(allowInteractive: any(named: 'allowInteractive')),
      ).thenAnswer(
        (_) async => Right(
          SyncAuthCredentials(
            syncToken: 'worker-jwt',
            workspaceId: 'merchant-ws',
            role: 'editor',
            obtainedAt: DateTime.utc(2026, 8, 5),
            expiresIn: 3600,
          ),
        ),
      );

      final useCase = EnsureProPlusSyncTokenUseCase(
        isMultiDeviceSyncUnlocked: unlocked,
        syncAuthBridgeRepository: bridge,
      );

      final result = await useCase();

      expect(result.isRight(), isTrue);
      verify(() => bridge.ensureValid()).called(1);
    });
  });
}
