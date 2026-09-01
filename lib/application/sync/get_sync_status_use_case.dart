import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Use case for querying the current sync status.
///
/// Returns a [SyncStatus] snapshot with last sync timestamp,
/// pending op count, and conflict count.
class GetSyncStatusUseCase {
  /// Creates the get sync status use case.
  const GetSyncStatusUseCase({
    required MergeEngineRepository mergeEngineRepository,
  }) : _mergeEngine = mergeEngineRepository;

  final MergeEngineRepository _mergeEngine;

  /// Returns the current sync status.
  Future<Either<Failure, SyncStatus>> call() {
    return _mergeEngine.getSyncStatus();
  }
}
