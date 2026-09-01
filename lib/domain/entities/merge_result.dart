import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'merge_result.freezed.dart';

/// Result of a merge operation performed by the Merge Engine.
///
/// Captures the full outcome: how many ops were applied, skipped,
/// what conflicts were surfaced, and which contacts need balance
/// recalculation.
///
/// Fields:
/// - [resultType]: Overall outcome classification.
/// - [appliedOpCount]: Number of remote ops successfully applied.
/// - [skippedOpCount]: Number of ops skipped (idempotency guard).
/// - [conflicts]: List of surfaced merge conflicts.
/// - [recalculatedContactIds]: Contact IDs whose balances were recalculated.
/// - [auditNotes]: Human-readable notes about auto-resolved conflicts.
@freezed
abstract class MergeResult with _$MergeResult {
  const factory MergeResult({
    required SyncResultType resultType,
    @Default(0) int appliedOpCount,
    @Default(0) int skippedOpCount,
    @Default([]) List<MergeConflict> conflicts,
    @Default([]) List<String> recalculatedContactIds,
    @Default([]) List<String> auditNotes,
  }) = _MergeResult;

  const MergeResult._();

  /// Creates a dormant result for non-Pro+ users.
  factory MergeResult.dormant() => const MergeResult(
        resultType: SyncResultType.dormant,
      );

  /// Whether the merge engine was dormant (non-Pro+ user).
  bool get isDormant => resultType == SyncResultType.dormant;

  /// Whether all ops were applied with no conflicts.
  bool get isClean =>
      resultType == SyncResultType.success && conflicts.isEmpty;

  /// Total number of ops processed (applied + skipped).
  int get totalProcessed => appliedOpCount + skippedOpCount;
}
