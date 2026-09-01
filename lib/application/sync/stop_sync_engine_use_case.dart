import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Stops Realtime wake-up subscriptions.
class StopSyncEngineUseCase {
  /// Creates the use case.
  const StopSyncEngineUseCase({
    required SyncEngineRepository syncEngineRepository,
  }) : _syncEngine = syncEngineRepository;

  final SyncEngineRepository _syncEngine;

  /// Tears down Realtime channels.
  Future<Either<Failure, Unit>> call() => _syncEngine.stopRealtime();
}
