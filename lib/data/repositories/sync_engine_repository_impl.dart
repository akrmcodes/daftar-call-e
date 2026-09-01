import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/network_retry_policy.dart';
import 'package:daftar/data/datasources/local/sync_outbound_ack_local_ds.dart';
import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:daftar/domain/repositories/sync_engine_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift + Dio implementation of [SyncEngineRepository].
class SyncEngineRepositoryImpl implements SyncEngineRepository {
  /// Creates the sync engine repository.
  const SyncEngineRepositoryImpl({
    required SyncRemoteDs remoteDs,
    required MergeEngineRepository mergeEngineRepository,
    required SyncOutboundAckLocalDs outboundAckDs,
  })  : _remoteDs = remoteDs,
        _mergeEngine = mergeEngineRepository,
        _outboundAckDs = outboundAckDs;

  final SyncRemoteDs _remoteDs;
  final MergeEngineRepository _mergeEngine;
  final SyncOutboundAckLocalDs _outboundAckDs;

  @override
  Stream<void> get changeWakeups => _remoteDs.changeWakeups;

  @override
  Future<Either<Failure, int>> pushPending({
    required String syncJwt,
    required String deviceId,
    required String workspaceRole,
  }) async {
    final pendingResult = await _mergeEngine.getPendingLocalOps();
    return pendingResult.fold(
      Left.new,
      (ops) async {
        if (ops.isEmpty) {
          return const Right(0);
        }

        final pushOps = ops
            .map(
              (op) => op.copyWith(role: workspaceRole),
            )
            .toList(growable: false);

        try {
          final pushResult = await NetworkRetryPolicy.execute(
            () => _remoteDs.pushOps(
              syncJwt: syncJwt,
              deviceId: deviceId,
              ops: pushOps,
            ),
          );

          return pushResult.fold(
            Left.new,
            (settled) async {
              await _outboundAckDs.recordAcks(
                settled.acks
                    .map(
                      (ack) => (
                        auditLogId: ack.auditLogId,
                        opSeq: ack.opSeq,
                        serverUpdatedAt: ack.serverUpdatedAt,
                      ),
                    )
                    .toList(growable: false),
              );
              await _quarantineRejections(settled.rejections, pushOps);
              return Right(settled.acks.length);
            },
          );
        } on SyncCapExceededException catch (e) {
          return Left(
            NetworkFailure(
              'Sync limit exceeded',
              code: e.code,
            ),
          );
        } on ServerException catch (e) {
          return Left(
            NetworkFailure(
              e.message,
              code: e.errorCode ?? 'sync_push_failed',
            ),
          );
        }
      },
    );
  }

  /// Settles refused ops locally so they leave the push queue.
  ///
  /// [pushed] supplies the entity each rejected audit-log id belongs to, so
  /// the surfaced conflict can name what the merchant actually lost.
  Future<void> _quarantineRejections(
    List<PushOpRejection> rejections,
    List<SyncOperation> pushed,
  ) async {
    if (rejections.isEmpty) {
      return;
    }

    final byId = {for (final op in pushed) op.id: op};
    final records = rejections
        .map((rejection) {
          final op = byId[rejection.auditLogId];
          if (op == null) {
            return null;
          }
          return (
            auditLogId: rejection.auditLogId,
            code: rejection.code,
            entityType: op.entityType,
            entityId: op.entityId,
            payload: op.fieldDeltas,
          );
        })
        .whereType<PushRejectionRecord>()
        .toList(growable: false);

    await _outboundAckDs.recordRejections(records);
  }

  @override
  Future<Either<Failure, MergeResult>> pullAndMerge({
    required String syncJwt,
  }) async {
    // A device that has been offline for a while can be more than one page
    // behind. Drain the backlog here instead of leaving the user on stale
    // financial data until some later trigger happens to fire again.
    var aggregate = const MergeResult(resultType: SyncResultType.success);

    for (var page = 0; page < _maxPullPagesPerCycle; page++) {
      final watermarkResult = await _mergeEngine.getPullWatermark();
      final sinceOpSeq = watermarkResult.getRight().toNullable();
      if (sinceOpSeq == null) {
        return Left(watermarkResult.getLeft().toNullable()!);
      }

      final Either<Failure, PullOpsPage> pullResult;
      try {
        pullResult = await NetworkRetryPolicy.execute(
          () => _remoteDs.pullOps(
            syncJwt: syncJwt,
            sinceOpSeq: sinceOpSeq,
          ),
        );
      } on ServerException catch (e) {
        return Left(NetworkFailure(e.message, code: 'sync_pull_failed'));
      }

      final pulled = pullResult.getRight().toNullable();
      if (pulled == null) {
        return Left(pullResult.getLeft().toNullable()!);
      }

      if (pulled.ops.isNotEmpty) {
        final mergeResult = await _mergeEngine.mergeRemoteOps(pulled.ops);
        final merged = mergeResult.getRight().toNullable();
        if (merged == null) {
          return Left(mergeResult.getLeft().toNullable()!);
        }
        aggregate = _combine(aggregate, merged);
      }

      // Advance to the server's cursor, not to what happened to arrive: the
      // server withholds ops it will not replay, so an empty page can still
      // move the cursor past them and a full drain depends on `has_more`.
      final recorded =
          await _mergeEngine.recordPullWatermark(pulled.nextSinceOpSeq);
      final watermarkFailure = recorded.getLeft().toNullable();
      if (watermarkFailure != null) {
        return Left(watermarkFailure);
      }

      if (!pulled.hasMore) {
        break;
      }
    }

    return Right(aggregate);
  }

  /// Bounds a single cycle so a pathological server cannot spin forever.
  static const int _maxPullPagesPerCycle = 25;

  MergeResult _combine(MergeResult a, MergeResult b) {
    final conflicts = [...a.conflicts, ...b.conflicts];
    return MergeResult(
      resultType:
          conflicts.isEmpty ? SyncResultType.success : SyncResultType.partial,
      appliedOpCount: a.appliedOpCount + b.appliedOpCount,
      skippedOpCount: a.skippedOpCount + b.skippedOpCount,
      conflicts: conflicts,
      recalculatedContactIds: {
        ...a.recalculatedContactIds,
        ...b.recalculatedContactIds,
      }.toList(growable: false),
      auditNotes: [...a.auditNotes, ...b.auditNotes],
    );
  }

  @override
  Future<Either<Failure, Unit>> startMerchantRealtime({
    required String syncJwt,
    required String workspaceId,
  }) async {
    try {
      await _remoteDs.startMerchantRealtime(
        syncJwt: syncJwt,
        workspaceId: workspaceId,
      );
      return const Right(unit);
    } on Exception catch (e) {
      return Left(NetworkFailure('Realtime start failed: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> stopRealtime() async {
    try {
      await _remoteDs.stopRealtime();
      return const Right(unit);
    } on Exception catch (e) {
      return Left(NetworkFailure('Realtime stop failed: $e'));
    }
  }

  @override
  Future<Either<Failure, MergeResult>> syncNow({
    required String syncJwt,
    required String deviceId,
    required String workspaceRole,
    required String workspaceId,
  }) async {
    final pushResult = await pushPending(
      syncJwt: syncJwt,
      deviceId: deviceId,
      workspaceRole: workspaceRole,
    );

    final pushFailure = pushResult.getLeft().toNullable();
    if (pushFailure != null) {
      return Left(pushFailure);
    }

    return pullAndMerge(syncJwt: syncJwt);
  }
}
