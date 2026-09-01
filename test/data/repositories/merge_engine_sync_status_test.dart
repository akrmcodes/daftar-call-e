import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/merge_engine_local_ds.dart';
import 'package:daftar/data/repositories/merge_engine_repository_impl.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/entities/workspace_membership_snapshot.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockActivationRepository extends Mock implements ActivationRepository {}

class _MockSyncAuthBridgeRepository extends Mock
    implements SyncAuthBridgeRepository {}

void main() {
  group('MergeEngineRepositoryImpl.getSyncStatus', () {
    late AppDatabase database;
    late MergeEngineRepositoryImpl repository;

    setUp(() async {
      DeviceIdentity.initializeForTest('device-test');
      database = AppDatabase(NativeDatabase.memory());
      repository = MergeEngineRepositoryImpl(
        mergeEngineDs: MergeEngineLocalDs(database),
        auditLogDs: AuditLogLocalDataSource(database),
        syncTokenStore: SyncTokenStore(),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('returns idle when never synced and no conflicts', () async {
      final result = await repository.getSyncStatus();

      result.fold(
        (_) => fail('unexpected failure'),
        (status) {
          expect(status.lastSyncResult, SyncResultType.idle);
          expect(status.isIdle, isTrue);
          expect(status.isDormant, isFalse);
          expect(status.hasNeverSynced, isTrue);
        },
      );
    });
  });

  group('SyncStatus entitlement gate', () {
    test('default SyncStatus is dormant for non-entitled users', () {
      const status = SyncStatus();
      expect(status.isDormant, isTrue);
      expect(status.isIdle, isFalse);
    });

    test('idle status is not dormant', () {
      const status = SyncStatus(lastSyncResult: SyncResultType.idle);
      expect(status.isDormant, isFalse);
      expect(status.isIdle, isTrue);
    });
  });

  group('IsMultiDeviceSyncUnlockedUseCase', () {
    late _MockActivationRepository activationRepository;
    late _MockSyncAuthBridgeRepository syncAuthBridgeRepository;
    late IsMultiDeviceSyncUnlockedUseCase useCase;

    setUp(() {
      activationRepository = _MockActivationRepository();
      syncAuthBridgeRepository = _MockSyncAuthBridgeRepository();
      useCase = IsMultiDeviceSyncUnlockedUseCase(
        activationRepository: activationRepository,
        syncAuthBridgeRepository: syncAuthBridgeRepository,
      );
    });

    test('returns false when multiDeviceSync is not in entitlement', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.multiDeviceSync),
      ).thenAnswer((_) async => false);
      when(() => syncAuthBridgeRepository.readLastKnownMembership())
          .thenAnswer((_) async => null);

      expect(await useCase(), isFalse);
    });

    test('contest kill-switch forces false even when entitled', () async {
      // AppConstants.kContestDisableMultiDeviceSync is true in this fork.
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.multiDeviceSync),
      ).thenAnswer((_) async => true);

      expect(await useCase(), isFalse);
      verifyNever(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.multiDeviceSync),
      );
    });

    test('contest kill-switch forces false for worker JWT', () async {
      when(
        () => activationRepository.isFeatureUnlocked(FeatureFlag.multiDeviceSync),
      ).thenAnswer((_) async => false);
      when(() => syncAuthBridgeRepository.readLastKnownMembership()).thenAnswer(
        (_) async => const WorkspaceMembershipSnapshot(
          workspaceId: 'ws-1',
          role: 'viewer',
        ),
      );

      expect(await useCase(), isFalse);
      verifyNever(() => syncAuthBridgeRepository.readLastKnownMembership());
    });

    test('Pro+ entitlement includes multiDeviceSync feature', () {
      final entitlement = Entitlement.forProPlus();
      expect(entitlement.hasFeature(FeatureFlag.multiDeviceSync), isTrue);
    });
  });
}
