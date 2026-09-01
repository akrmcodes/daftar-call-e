import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for the Sync Engine orchestrator (Stage 8.4).
///
/// Coordinates push/pull against Edge Functions, Realtime wake-ups,
/// and delegates merge to the Merge Engine. Never blocks local CRUD.
abstract class SyncEngineRepository {
  /// Pushes unacknowledged local audit ops to the server.
  Future<Either<Failure, int>> pushPending({
    required String syncJwt,
    required String deviceId,
    required String workspaceRole,
  });

  /// Pulls remote ops since the local watermark and merges them.
  Future<Either<Failure, MergeResult>> pullAndMerge({
    required String syncJwt,
  });

  /// Starts merchant Realtime subscriptions for change wake-ups.
  Future<Either<Failure, Unit>> startMerchantRealtime({
    required String syncJwt,
    required String workspaceId,
  });

  /// Stops Realtime subscriptions.
  Future<Either<Failure, Unit>> stopRealtime();

  /// Full sync cycle: push pending → pull → merge.
  Future<Either<Failure, MergeResult>> syncNow({
    required String syncJwt,
    required String deviceId,
    required String workspaceRole,
    required String workspaceId,
  });

  /// Stream of Realtime wake-up signals (debounced by orchestrator).
  Stream<void> get changeWakeups;
}
