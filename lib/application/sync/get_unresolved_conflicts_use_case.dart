import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Use case for querying unresolved merge conflicts.
///
/// Returns all conflicts that have not been resolved via the
/// Smart Merge UI (Stage 9). Used by the Sync Report screen
/// and conflict count badges.
class GetUnresolvedConflictsUseCase {
  /// Creates the get unresolved conflicts use case.
  const GetUnresolvedConflictsUseCase({
    required MergeEngineRepository mergeEngineRepository,
  }) : _mergeEngine = mergeEngineRepository;

  final MergeEngineRepository _mergeEngine;

  /// Returns all unresolved merge conflicts.
  Future<Either<Failure, List<MergeConflict>>> call() {
    return _mergeEngine.getUnresolvedConflicts();
  }
}
