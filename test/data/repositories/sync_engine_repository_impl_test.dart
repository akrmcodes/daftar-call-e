import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/network_retry_policy.dart';
import 'package:daftar/data/datasources/local/sync_outbound_ack_local_ds.dart';
import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:daftar/data/repositories/sync_engine_repository_impl.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/domain/repositories/merge_engine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncRemoteDs extends Mock implements SyncRemoteDs {}

class MockSyncOutboundAckLocalDs extends Mock
    implements SyncOutboundAckLocalDs {}

/// Records the watermark the way the real merge engine does so pagination can
/// be exercised without a database.
class FakeMergeEngineRepository implements MergeEngineRepository {
  FakeMergeEngineRepository();

  int watermark = 0;
  int pullWatermark = 0;
  final List<List<SyncOperation>> mergedBatches = [];
  Failure? mergeFailure;

  @override
  Future<Either<Failure, MergeResult>> mergeRemoteOps(
    List<SyncOperation> ops,
  ) async {
    final failure = mergeFailure;
    if (failure != null) {
      return Left(failure);
    }
    mergedBatches.add(ops);
    for (final op in ops) {
      if (op.opSeq > watermark) {
        watermark = op.opSeq;
      }
    }
    return Right(
      MergeResult(
        resultType: SyncResultType.success,
        appliedOpCount: ops.length,
      ),
    );
  }

  @override
  Future<Either<Failure, int>> getLastAppliedOpSeq() async =>
      Right(watermark);

  @override
  Future<Either<Failure, int>> getPullWatermark() async =>
      Right(pullWatermark);

  @override
  Future<Either<Failure, Unit>> recordPullWatermark(int nextSinceOpSeq) async {
    if (nextSinceOpSeq > pullWatermark) {
      pullWatermark = nextSinceOpSeq;
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<SyncOperation>>> getPendingLocalOps({
    DateTime? since,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<MergeConflict>>> getUnresolvedConflicts() async =>
      const Right([]);

  @override
  Future<Either<Failure, Unit>> resolveConflict({
    required String conflictId,
    required bool chooseLocal,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, SyncStatus>> getSyncStatus() async =>
      const Right(SyncStatus());
}

void main() {
  late MockSyncRemoteDs remoteDs;
  late MockSyncOutboundAckLocalDs ackDs;
  late FakeMergeEngineRepository mergeEngine;
  late SyncEngineRepositoryImpl sut;

  const jwt = 'sync-jwt';

  SyncOperation op(int seq) => SyncOperation(
        id: 'op-$seq',
        entityType: 'transaction',
        entityId: 'txn-$seq',
        action: 'CREATE',
        deviceId: 'device-remote',
        role: 'editor',
        localTimestamp: DateTime.utc(2026),
        serverUpdatedAt: DateTime.utc(2026),
        opSeq: seq,
      );

  setUpAll(() {
    // Keep retry backoff out of the wall clock.
    NetworkRetryPolicy.debugDelay = (_) async {};
  });

  tearDownAll(() {
    NetworkRetryPolicy.debugDelay = null;
  });

  setUp(() {
    remoteDs = MockSyncRemoteDs();
    ackDs = MockSyncOutboundAckLocalDs();
    mergeEngine = FakeMergeEngineRepository();
    sut = SyncEngineRepositoryImpl(
      remoteDs: remoteDs,
      mergeEngineRepository: mergeEngine,
      outboundAckDs: ackDs,
    );
  });

  group('pullAndMerge backlog draining', () {
    test('keeps pulling while the server returns full pages', () async {
      const pageSize = SyncRemoteDs.defaultPullLimit;
      final firstPage = List.generate(pageSize, (i) => op(i + 1));
      final secondPage = [op(pageSize + 1), op(pageSize + 2)];

      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenAnswer((invocation) async {
        final since = invocation.namedArguments[#sinceOpSeq] as int;
        if (since == 0) {
          return PullOpsPage(
            ops: firstPage,
            nextSinceOpSeq: pageSize,
            hasMore: true,
          );
        }
        return PullOpsPage(
          ops: secondPage,
          nextSinceOpSeq: pageSize + 2,
          hasMore: false,
        );
      });

      final result = await sut.pullAndMerge(syncJwt: jwt);

      expect(mergeEngine.mergedBatches, hasLength(2));
      expect(mergeEngine.pullWatermark, pageSize + 2);
      result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (merged) => expect(merged.appliedOpCount, pageSize + 2),
      );
    });

    test('stops after a short page', () async {
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenAnswer(
        (_) async => PullOpsPage(
          ops: [op(1)],
          nextSinceOpSeq: 1,
          hasMore: false,
        ),
      );

      await sut.pullAndMerge(syncJwt: jwt);

      expect(mergeEngine.mergedBatches, hasLength(1));
      verify(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).called(1);
    });

    test('an empty first page merges nothing and succeeds', () async {
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenAnswer(
        (_) async => const PullOpsPage(
          ops: [],
          nextSinceOpSeq: 0,
          hasMore: false,
        ),
      );

      final result = await sut.pullAndMerge(syncJwt: jwt);

      expect(mergeEngine.mergedBatches, isEmpty);
      expect(result.isRight(), isTrue);
    });
  });

  group('pullAndMerge failure paths', () {
    test('an expired token surfaces as a NetworkFailure, never a throw',
        () async {
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenThrow(
        const ServerException(
          'JWT expired',
          statusCode: 401,
          errorCode: 'token_expired',
        ),
      );

      final result = await sut.pullAndMerge(syncJwt: jwt);

      result.fold(
        (failure) {
          expect(failure, isA<NetworkFailure>());
          expect(failure.code, 'token_expired');
        },
        (_) => fail('Expected a failure'),
      );
    });

    test('a malformed payload is not retried into oblivion', () async {
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenThrow(
        const ServerException(
          'Malformed sync payload: missing op.id',
          statusCode: 422,
          errorCode: 'sync_payload_malformed',
        ),
      );

      final result = await sut.pullAndMerge(syncJwt: jwt);

      expect(result.isLeft(), isTrue);
      verify(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).called(1);
    });

    test('offline transport errors exhaust retries and stay a Left', () async {
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenThrow(const ServerException('Network is unreachable'));

      final result = await sut.pullAndMerge(syncJwt: jwt);

      result.fold(
        (failure) => expect(failure.code, 'sync_retry_exhausted'),
        (_) => fail('Expected a failure'),
      );
      verify(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).called(NetworkRetryPolicy.maxAttempts);
    });

    test('a merge failure aborts the drain instead of advancing blindly',
        () async {
      mergeEngine.mergeFailure = const DatabaseFailure('merge exploded');
      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenAnswer(
        (_) async => PullOpsPage(
          ops: [op(1)],
          nextSinceOpSeq: 1,
          hasMore: false,
        ),
      );

      final result = await sut.pullAndMerge(syncJwt: jwt);

      expect(result.isLeft(), isTrue);
      expect(mergeEngine.pullWatermark, 0);
    });
  });

  group('syncNow ordering', () {
    test('a push failure stops the cycle before pulling', () async {
      when(
        () => remoteDs.pushOps(
          syncJwt: any(named: 'syncJwt'),
          deviceId: any(named: 'deviceId'),
          ops: any(named: 'ops'),
        ),
      ).thenThrow(const ServerException('boom', statusCode: 500));

      // No pending ops means push short-circuits to success, so seed one.
      final engine = _FailingPushMergeEngine();
      final repo = SyncEngineRepositoryImpl(
        remoteDs: remoteDs,
        mergeEngineRepository: engine,
        outboundAckDs: ackDs,
      );

      final result = await repo.syncNow(
        syncJwt: jwt,
        deviceId: 'device-1',
        workspaceRole: 'editor',
        workspaceId: 'ws-1',
      );

      expect(result.isLeft(), isTrue);
      verifyNever(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      );
    });
  });

  group('MergeResult aggregation', () {
    test('conflicts from any page mark the whole cycle partial', () async {
      final engine = _ConflictingMergeEngine();
      final repo = SyncEngineRepositoryImpl(
        remoteDs: remoteDs,
        mergeEngineRepository: engine,
        outboundAckDs: ackDs,
      );

      when(
        () => remoteDs.pullOps(
          syncJwt: any(named: 'syncJwt'),
          sinceOpSeq: any(named: 'sinceOpSeq'),
        ),
      ).thenAnswer(
        (_) async => PullOpsPage(
          ops: [op(1)],
          nextSinceOpSeq: 1,
          hasMore: false,
        ),
      );

      final result = await repo.pullAndMerge(syncJwt: jwt);

      result.fold(
        (failure) => fail('unexpected failure: $failure'),
        (merged) {
          expect(merged.resultType, SyncResultType.partial);
          expect(merged.conflicts, hasLength(1));
        },
      );
    });
  });
}

class _FailingPushMergeEngine extends FakeMergeEngineRepository {
  @override
  Future<Either<Failure, List<SyncOperation>>> getPendingLocalOps({
    DateTime? since,
  }) async =>
      Right([
        SyncOperation(
          id: 'pending-1',
          entityType: 'transaction',
          entityId: 'txn-1',
          action: 'CREATE',
          deviceId: 'device-1',
          role: 'editor',
          localTimestamp: DateTime.utc(2026),
          serverUpdatedAt: DateTime.utc(2026),
          opSeq: 0,
        ),
      ]);
}

class _ConflictingMergeEngine extends FakeMergeEngineRepository {
  @override
  Future<Either<Failure, MergeResult>> mergeRemoteOps(
    List<SyncOperation> ops,
  ) async {
    mergedBatches.add(ops);
    return Right(
      MergeResult(
        resultType: SyncResultType.partial,
        skippedOpCount: ops.length,
        conflicts: [
          MergeConflict(
            id: 'conflict-1',
            entityType: 'transaction',
            entityId: 'txn-1',
            conflictType: ConflictType.ambiguous,
            localSnapshot: '{}',
            remoteSnapshot: '{}',
            detectedAt: DateTime.utc(2026),
          ),
        ],
      ),
    );
  }
}
