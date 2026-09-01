import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Pulls remote ops since the local watermark and merges them.
///
/// Read-only with respect to the server, so every role — including viewer —
/// may call it. Returns a dormant [MergeResult] when sync is locked rather
/// than a failure, because a locked device is not in an error state.
class PullAndMergeUseCase {
  /// Creates the use case.
  const PullAndMergeUseCase({
    required SyncEngineRepository syncEngineRepository,
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
  })  : _syncEngine = syncEngineRepository,
        _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked;

  final SyncEngineRepository _syncEngine;
  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;

  /// Pulls and merges the remote op backlog.
  Future<Either<Failure, MergeResult>> call({required String syncJwt}) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return const Right(MergeResult(resultType: SyncResultType.dormant));
    }

    return _syncEngine.pullAndMerge(syncJwt: syncJwt);
  }
}
