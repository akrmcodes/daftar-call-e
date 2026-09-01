import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Pushes unacknowledged local ops to the server (diagnostic Upload).
///
/// Business rules enforced here:
/// - Multi-device sync must be unlocked (Pro+ or an active worker JWT).
/// - Viewers may never push — the check fails closed on an unknown role.
///
/// Returns:
/// - [AuthFailure] `sync_not_entitled` when sync is locked.
/// - [AuthFailure] `sync_viewer_blocked` when the caller cannot write.
/// - [NetworkFailure] propagated from the transport.
class PushPendingOpsUseCase {
  /// Creates the use case.
  const PushPendingOpsUseCase({
    required SyncEngineRepository syncEngineRepository,
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
  })  : _syncEngine = syncEngineRepository,
        _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked;

  final SyncEngineRepository _syncEngine;
  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;

  /// Pushes pending ops, returning the number the server acknowledged.
  Future<Either<Failure, int>> call({
    required String syncJwt,
    required WorkspaceRole? workspaceRole,
  }) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return const Left(
        AuthFailure(
          'Multi-device sync is not unlocked.',
          code: 'sync_not_entitled',
        ),
      );
    }

    if (workspaceRole == null || workspaceRole == WorkspaceRole.viewer) {
      return const Left(
        AuthFailure(
          'Viewer role cannot push sync changes.',
          code: 'sync_viewer_blocked',
        ),
      );
    }

    return _syncEngine.pushPending(
      syncJwt: syncJwt,
      deviceId: DeviceIdentity.current,
      workspaceRole: workspaceRole.name,
    );
  }
}
