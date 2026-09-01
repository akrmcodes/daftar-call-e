import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/entities/merge_result.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for the Merge Engine — the core conflict resolution system.
///
/// The Merge Engine replays remote ops against local state using
/// field-level Last-Write-Wins (LWW) with deterministic tiebreakers.
/// All merge operations run inside a single Drift transaction for
/// ACID guarantees.
///
/// ## Financial Safety Rules
///
/// 1. **Modification > Deletion**: If a delete and edit race, the edit
///    survives (un-delete + audit note).
/// 2. **Transactions are immutable facts**: Concurrent inserts are
///    always additive — they NEVER conflict.
/// 3. **Money is never merged arithmetically**: Balances are recalculated
///    from the surviving transaction set after every merge.
///
/// ## Pro+ Entitlement
///
/// The merge engine is a Pro+ exclusive feature. Callers MUST verify
/// `FeatureFlag.multiDeviceSync` before invoking merge operations.
/// The use case layer enforces this gate.
abstract class MergeEngineRepository {
  /// Replays a batch of remote operations against local state.
  ///
  /// Operations are ordered by [SyncOperation.opSeq] (server-assigned).
  /// Each op is deduped by `(entityId, deviceId, id)` before applying.
  ///
  /// Returns [MergeResult] with applied/skipped counts, surfaced
  /// conflicts, and contacts needing balance recalculation.
  Future<Either<Failure, MergeResult>> mergeRemoteOps(
    List<SyncOperation> ops,
  );

  /// Returns local ops created since [since] that haven't been pushed.
  ///
  /// Used by the push path (Stage 8.9) to send local mutations to the server.
  Future<Either<Failure, List<SyncOperation>>> getPendingLocalOps({
    DateTime? since,
  });

  /// Returns all unresolved merge conflicts.
  ///
  /// Used by the Smart Merge UI (Stage 9) and the Sync Report screen.
  Future<Either<Failure, List<MergeConflict>>> getUnresolvedConflicts();

  /// Resolves a specific merge conflict.
  ///
  /// [conflictId] is the UUID of the [MergeConflict] to resolve.
  /// [chooseLocal] determines whether the local or remote snapshot wins.
  Future<Either<Failure, Unit>> resolveConflict({
    required String conflictId,
    required bool chooseLocal,
  });

  /// Returns the current sync status summary.
  Future<Either<Failure, SyncStatus>> getSyncStatus();

  /// Returns the highest applied op_seq.
  Future<Either<Failure, int>> getLastAppliedOpSeq();

  /// Returns the cursor to send as `since_op_seq` on the next pull.
  ///
  /// This is the server's own cursor, not `MAX(op_seq)` of applied ops: the
  /// server withholds ops this workspace must not replay, so deriving the
  /// cursor from what was applied would re-request the withheld range
  /// forever and stall the drain there.
  Future<Either<Failure, int>> getPullWatermark();

  /// Persists the server-supplied cursor after a pull page is merged.
  ///
  /// Monotonic — a stale or out-of-order response can never rewind it.
  Future<Either<Failure, Unit>> recordPullWatermark(int nextSinceOpSeq);
}
