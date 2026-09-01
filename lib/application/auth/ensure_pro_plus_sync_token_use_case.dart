import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/sync_auth_bridge_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Ensures a sync JWT when multi-device sync is unlocked.
///
/// Free / Pro tiers without a worker seat return [Right(null)] without
/// calling the Auth Bridge.
class EnsureProPlusSyncTokenUseCase {
  /// Creates the use case.
  const EnsureProPlusSyncTokenUseCase({
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
    required SyncAuthBridgeRepository syncAuthBridgeRepository,
  })  : _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked,
        _syncAuthBridge = syncAuthBridgeRepository;

  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;
  final SyncAuthBridgeRepository _syncAuthBridge;

  /// Returns credentials, `null` when sync is not licensed, or a [Failure].
  Future<Either<Failure, SyncAuthCredentials?>> call({
    bool allowInteractive = false,
  }) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return const Right(null);
    }
    final result = await _syncAuthBridge.ensureValid(
      allowInteractive: allowInteractive,
    );
    return result.map((credentials) => credentials);
  }
}
