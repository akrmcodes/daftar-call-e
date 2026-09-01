import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';

/// Whether Pro+ multi-device sync is unlocked for the current merchant.
///
/// Workers invited to a Pro+ workspace inherit sync via their sync JWT role
/// even when their personal device lacks a Pro+ activation code.
///
/// Contest quarantine: when [AppConstants.kContestDisableMultiDeviceSync] is
/// true, always returns `false` (Stage 8 disabled for Closing Agent fork).
class IsMultiDeviceSyncUnlockedUseCase {
  /// Creates the use case.
  const IsMultiDeviceSyncUnlockedUseCase({
    required ActivationRepository activationRepository,
    required SyncAuthBridgeRepository syncAuthBridgeRepository,
  })  : _activation = activationRepository,
        _syncAuthBridge = syncAuthBridgeRepository;

  final ActivationRepository _activation;
  final SyncAuthBridgeRepository _syncAuthBridge;

  /// Returns true when [FeatureFlag.multiDeviceSync] is unlocked locally or
  /// when a valid worker sync JWT is present (editor/viewer).
  Future<bool> call() async {
    // Contest quarantine — Stage 8 disabled.
    if (AppConstants.kContestDisableMultiDeviceSync) {
      return false;
    }

    final entitled = await _activation.isFeatureUnlocked(
      FeatureFlag.multiDeviceSync,
    );
    if (entitled) {
      return true;
    }

    final snapshot = await _syncAuthBridge.readLastKnownMembership();
    if (snapshot == null) {
      return false;
    }

    final role = WorkspaceRole.fromString(snapshot.role);
    return role == WorkspaceRole.editor || role == WorkspaceRole.viewer;
  }
}
