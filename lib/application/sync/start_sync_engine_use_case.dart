import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Starts merchant Realtime wake-up subscriptions when entitled.
class StartSyncEngineUseCase {
  /// Creates the use case.
  const StartSyncEngineUseCase({
    required SyncEngineRepository syncEngineRepository,
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
  })  : _syncEngine = syncEngineRepository,
        _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked;

  final SyncEngineRepository _syncEngine;
  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;

  /// Starts Realtime for owner/editor merchant paths only.
  Future<Either<Failure, Unit>> call({
    required String syncJwt,
    required String workspaceId,
    required WorkspaceRole? workspaceRole,
  }) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return const Right(unit);
    }

    if (workspaceRole == null ||
        workspaceRole == WorkspaceRole.viewer) {
      return const Right(unit);
    }

    return _syncEngine.startMerchantRealtime(
      syncJwt: syncJwt,
      workspaceId: workspaceId,
    );
  }
}
