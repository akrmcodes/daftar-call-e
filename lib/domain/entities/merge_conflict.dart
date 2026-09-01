import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'merge_conflict.freezed.dart';

/// A detected merge conflict that requires user attention.
///
/// Created by the Merge Engine (Stage 8.4) when an ambiguous or
/// un-auto-resolvable conflict is detected during op-log replay.
/// Surfaced to the Smart Merge UI (Stage 9) for manual resolution.
///
/// Fields:
/// - [id]: UUID v4 primary key for this conflict record.
/// - [entityType]: Type of the conflicting entity ('ledger', 'contact', 'transaction').
/// - [entityId]: UUID of the conflicting entity.
/// - [conflictType]: Classification of the conflict.
/// - [localSnapshot]: JSON snapshot of the local entity state at conflict time.
/// - [remoteSnapshot]: JSON snapshot of the remote entity state at conflict time.
/// - [detectedAt]: UTC timestamp when the conflict was detected.
/// - [resolvedAt]: UTC timestamp when the conflict was resolved (null if unresolved).
/// - [isResolved]: Whether this conflict has been resolved.
@freezed
abstract class MergeConflict with _$MergeConflict {
  const factory MergeConflict({
    required String id,
    required String entityType,
    required String entityId,
    required ConflictType conflictType,
    required String localSnapshot,
    required String remoteSnapshot,
    required DateTime detectedAt,
    DateTime? resolvedAt,
    @Default(false) bool isResolved,
  }) = _MergeConflict;
}
