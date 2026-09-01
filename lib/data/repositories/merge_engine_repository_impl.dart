import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/merge_engine_local_ds.dart';
import 'package:daftar/data/models/sync_operation_model.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [MergeEngineRepository].
///
/// Delegates to [MergeEngineLocalDs] for the core merge logic and
/// [AuditLogLocalDataSource] for local op retrieval (push path).
class MergeEngineRepositoryImpl implements MergeEngineRepository {
  /// Creates the merge engine repository.
  const MergeEngineRepositoryImpl({
    required MergeEngineLocalDs mergeEngineDs,
    required AuditLogLocalDataSource auditLogDs,
    required SyncTokenStore syncTokenStore,
  })  : _mergeEngineDs = mergeEngineDs,
        _auditLogDs = auditLogDs,
        _syncTokenStore = syncTokenStore;

  final MergeEngineLocalDs _mergeEngineDs;
  final AuditLogLocalDataSource _auditLogDs;
  final SyncTokenStore _syncTokenStore;

  @override
  Future<Either<Failure, MergeResult>> mergeRemoteOps(
    List<SyncOperation> ops,
  ) async {
    try {
      if (ops.isEmpty) {
        return const Right(
          MergeResult(
            resultType: SyncResultType.success,
          ),
        );
      }

      final models =
          ops.map(SyncOperationModel.fromDomain).toList(growable: false);

      final localRole = await _resolveLocalRole();
      final result = await _mergeEngineDs.applyRemoteOps(
        models,
        localRoleOverride: localRole,
      );

      final conflicts = result.conflicts
          .map((c) => c.toDomain())
          .toList(growable: false);

      final resultType = conflicts.isEmpty
          ? SyncResultType.success
          : SyncResultType.partial;

      return Right(
        MergeResult(
          resultType: resultType,
          appliedOpCount: result.applied,
          skippedOpCount: result.skipped,
          conflicts: conflicts,
          recalculatedContactIds: result.recalculatedContactIds,
          auditNotes: result.auditNotes,
        ),
      );
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Merge engine failed: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<SyncOperation>>> getPendingLocalOps({
    DateTime? since,
  }) async {
    try {
      final logs = since == null
          ? await _auditLogDs.getPendingPushLogs()
          : await _auditLogDs.getLogsSince(since);

      // RBAC fails closed: never stamp an op with a role we cannot prove.
      // The push path overwrites this with the server-resolved role.
      final role = await _resolveLocalRole();
      final ops = logs.map((log) {
        return SyncOperation(
          id: log.id,
          entityType: log.entityType,
          entityId: log.entityId,
          action: log.action,
          deviceId: log.deviceId,
          role: role,
          localTimestamp: log.timestamp,
          serverUpdatedAt: log.timestamp,
          opSeq: 0,
          fieldDeltas: log.payload,
        );
      }).toList(growable: false);

      return Right(ops);
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to get pending local ops: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, List<MergeConflict>>> getUnresolvedConflicts() async {
    try {
      final conflicts = await _mergeEngineDs.getUnresolvedConflicts();
      return Right(
        conflicts.map((c) => c.toDomain()).toList(growable: false),
      );
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to get unresolved conflicts: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> resolveConflict({
    required String conflictId,
    required bool chooseLocal,
  }) async {
    try {
      await _mergeEngineDs.resolveConflict(
        conflictId: conflictId,
        chooseLocal: chooseLocal,
      );
      return const Right(unit);
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to resolve conflict: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, SyncStatus>> getSyncStatus() async {
    try {
      final lastOpSeq = await _mergeEngineDs.getLastAppliedOpSeq();
      final lastSyncAt = await _mergeEngineDs.getLastAppliedServerUpdatedAt();
      final unresolvedCount =
          await _mergeEngineDs.getUnresolvedConflictCount();
      final pendingOpCount = await _auditLogDs.countPendingPushLogs();

      final SyncResultType resultType;
      if (lastOpSeq == 0 && unresolvedCount == 0) {
        resultType = SyncResultType.idle;
      } else if (unresolvedCount > 0) {
        resultType = SyncResultType.partial;
      } else {
        resultType = SyncResultType.success;
      }

      return Right(
        SyncStatus(
          lastSyncAt: lastSyncAt,
          pendingOpCount: pendingOpCount,
          lastSyncResult: resultType,
          mergedOpCount: lastOpSeq,
          conflictCount: unresolvedCount,
        ),
      );
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to get sync status: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> getLastAppliedOpSeq() async {
    try {
      final opSeq = await _mergeEngineDs.getLastAppliedOpSeq();
      return Right(opSeq);
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to get last applied op_seq: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> getPullWatermark() async {
    try {
      return Right(await _mergeEngineDs.getPullWatermark());
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to get pull watermark: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> recordPullWatermark(int nextSinceOpSeq) async {
    try {
      await _mergeEngineDs.recordPullWatermark(nextSinceOpSeq);
      return const Right(unit);
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to record pull watermark: $e'),
      );
    }
  }

  /// Resolves this device's workspace role, failing closed.
  ///
  /// An unknown role must never be promoted: the role drives the merge
  /// tiebreaker, so guessing high lets this device win writes it has no
  /// authority for.
  Future<String> _resolveLocalRole() async {
    final token = await _syncTokenStore.read();
    if (token != null && token.role.isNotEmpty) {
      return token.role;
    }

    final membership = await _syncTokenStore.readLastKnownMembership();
    if (membership != null && membership.role.isNotEmpty) {
      return membership.role;
    }

    return 'viewer';
  }
}
