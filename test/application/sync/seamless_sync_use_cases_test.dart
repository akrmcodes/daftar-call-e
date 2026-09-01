import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/application/sync/start_sync_engine_use_case.dart';
import 'package:daftar/application/sync/sync_now_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncEngineRepository extends Mock implements SyncEngineRepository {}

class MockIsMultiDeviceSyncUnlockedUseCase extends Mock
    implements IsMultiDeviceSyncUnlockedUseCase {}

void main() {
  late MockSyncEngineRepository syncEngine;
  late MockIsMultiDeviceSyncUnlockedUseCase unlocked;

  setUp(() {
    DeviceIdentity.initializeForTest('test-device-id');
    syncEngine = MockSyncEngineRepository();
    unlocked = MockIsMultiDeviceSyncUnlockedUseCase();
  });

  group('SyncNowUseCase', () {
    test('returns dormant when sync is not unlocked', () async {
      when(() => unlocked.call()).thenAnswer((_) async => false);

      final useCase = SyncNowUseCase(
        syncEngineRepository: syncEngine,
        isMultiDeviceSyncUnlocked: unlocked,
      );

      final result = await useCase(
        syncJwt: 'jwt',
        workspaceRole: 'editor',
        workspaceId: 'ws-1',
      );

      expect(
        result,
        const Right<Failure, MergeResult>(
          MergeResult(resultType: SyncResultType.dormant),
        ),
      );
      verifyNever(
        () => syncEngine.syncNow(
          syncJwt: any(named: 'syncJwt'),
          deviceId: any(named: 'deviceId'),
          workspaceRole: any(named: 'workspaceRole'),
          workspaceId: any(named: 'workspaceId'),
        ),
      );
    });

    test('runs sync for worker without personal Pro+ when unlocked', () async {
      when(() => unlocked.call()).thenAnswer((_) async => true);
      when(
        () => syncEngine.syncNow(
          syncJwt: any(named: 'syncJwt'),
          deviceId: any(named: 'deviceId'),
          workspaceRole: any(named: 'workspaceRole'),
          workspaceId: any(named: 'workspaceId'),
        ),
      ).thenAnswer(
        (_) async => const Right(MergeResult(resultType: SyncResultType.success)),
      );

      final useCase = SyncNowUseCase(
        syncEngineRepository: syncEngine,
        isMultiDeviceSyncUnlocked: unlocked,
      );

      final result = await useCase(
        syncJwt: 'worker-jwt',
        workspaceRole: 'editor',
        workspaceId: 'merchant-ws',
      );

      expect(result.isRight(), isTrue);
      verify(() => unlocked.call()).called(1);
      verify(
        () => syncEngine.syncNow(
          syncJwt: 'worker-jwt',
          deviceId: 'test-device-id',
          workspaceRole: 'editor',
          workspaceId: 'merchant-ws',
        ),
      ).called(1);
    });
  });

  group('StartSyncEngineUseCase', () {
    test('starts Realtime for editor worker when unlocked', () async {
      when(() => unlocked.call()).thenAnswer((_) async => true);
      when(
        () => syncEngine.startMerchantRealtime(
          syncJwt: any(named: 'syncJwt'),
          workspaceId: any(named: 'workspaceId'),
        ),
      ).thenAnswer((_) async => const Right(unit));

      final useCase = StartSyncEngineUseCase(
        syncEngineRepository: syncEngine,
        isMultiDeviceSyncUnlocked: unlocked,
      );

      final result = await useCase(
        syncJwt: 'worker-jwt',
        workspaceId: 'merchant-ws',
        workspaceRole: WorkspaceRole.editor,
      );

      expect(result, const Right<Failure, Unit>(unit));
      verify(
        () => syncEngine.startMerchantRealtime(
          syncJwt: 'worker-jwt',
          workspaceId: 'merchant-ws',
        ),
      ).called(1);
    });

    test('skips Realtime for viewer even when unlocked', () async {
      when(() => unlocked.call()).thenAnswer((_) async => true);

      final useCase = StartSyncEngineUseCase(
        syncEngineRepository: syncEngine,
        isMultiDeviceSyncUnlocked: unlocked,
      );

      final result = await useCase(
        syncJwt: 'viewer-jwt',
        workspaceId: 'merchant-ws',
        workspaceRole: WorkspaceRole.viewer,
      );

      expect(result, const Right<Failure, Unit>(unit));
      verifyNever(
        () => syncEngine.startMerchantRealtime(
          syncJwt: any(named: 'syncJwt'),
          workspaceId: any(named: 'workspaceId'),
        ),
      );
    });
  });
}
