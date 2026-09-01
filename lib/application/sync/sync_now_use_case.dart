import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Runs a full sync cycle: push pending → pull → merge.
class SyncNowUseCase {
  /// Creates the use case.
  const SyncNowUseCase({
    required SyncEngineRepository syncEngineRepository,
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
  })  : _syncEngine = syncEngineRepository,
        _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked;

  final SyncEngineRepository _syncEngine;
  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;

  /// Executes sync when multi-device sync is unlocked (Pro+ or worker JWT).
  Future<Either<Failure, MergeResult>> call({
    required String syncJwt,
    required String workspaceRole,
    required String workspaceId,
  }) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return const Right(MergeResult(resultType: SyncResultType.dormant));
    }

    return _syncEngine.syncNow(
      syncJwt: syncJwt,
      deviceId: DeviceIdentity.current,
      workspaceRole: workspaceRole,
      workspaceId: workspaceId,
    );
  }
}
