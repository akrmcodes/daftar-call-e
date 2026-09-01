import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Current sync state visible to the presentation layer.
///
/// Provides a summary of the last sync operation and pending work.
/// Updated after every merge cycle by the Sync Orchestrator.
///
/// Fields:
/// - [lastSyncAt]: UTC timestamp of the last successful sync (null if never synced).
/// - [pendingOpCount]: Number of local ops not yet pushed to the server.
/// - [lastSyncResult]: Outcome of the most recent sync attempt.
/// - [mergedOpCount]: Number of remote ops applied in the last merge.
/// - [conflictCount]: Number of unresolved conflicts.
@freezed
abstract class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    DateTime? lastSyncAt,
    @Default(0) int pendingOpCount,
    @Default(SyncResultType.dormant) SyncResultType lastSyncResult,
    @Default(0) int mergedOpCount,
    @Default(0) int conflictCount,
  }) = _SyncStatus;

  const SyncStatus._();

  /// Whether sync has never been performed.
  bool get hasNeverSynced => lastSyncAt == null;

  /// Whether there are pending local operations to push.
  bool get hasPendingOps => pendingOpCount > 0;

  /// Whether there are unresolved merge conflicts.
  bool get hasConflicts => conflictCount > 0;

  /// Whether multi-device sync is gated (non-Pro+ user).
  ///
  /// Distinct from [isIdle], which means entitled but never synced.
  bool get isDormant => lastSyncResult == SyncResultType.dormant;

  /// Whether the user is entitled but has not completed a sync cycle yet.
  bool get isIdle => lastSyncResult == SyncResultType.idle;
}
