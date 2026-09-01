import 'package:daftar/application/sync/is_multi_device_sync_unlocked_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Use case for merging remote operations into local state.
///
/// Before ANY merge operation, checks multi-device sync unlock (Pro+ or worker
/// JWT). If not unlocked, returns [MergeResult.dormant()].
class MergeRemoteOpsUseCase {
  /// Creates the merge remote ops use case.
  const MergeRemoteOpsUseCase({
    required MergeEngineRepository mergeEngineRepository,
    required IsMultiDeviceSyncUnlockedUseCase isMultiDeviceSyncUnlocked,
  })  : _mergeEngine = mergeEngineRepository,
        _isMultiDeviceSyncUnlocked = isMultiDeviceSyncUnlocked;

  final MergeEngineRepository _mergeEngine;
  final IsMultiDeviceSyncUnlockedUseCase _isMultiDeviceSyncUnlocked;

  /// Merges a batch of remote operations.
  Future<Either<Failure, MergeResult>> call(
    List<SyncOperation> ops,
  ) async {
    final unlocked = await _isMultiDeviceSyncUnlocked.call();
    if (!unlocked) {
      return Right(MergeResult.dormant());
    }

    return _mergeEngine.mergeRemoteOps(ops);
  }
}
