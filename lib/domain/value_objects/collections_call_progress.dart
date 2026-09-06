import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:equatable/equatable.dart';

/// One row in the call progress rail.
class CollectionsCallProgressRow extends Equatable {
  /// Creates a progress row.
  const CollectionsCallProgressRow({
    required this.contactId,
    required this.status,
    this.runId,
  });

  /// Drift contact id.
  final String contactId;

  /// Current CALL-E row status.
  final CollectionsCallRowStatus status;

  /// CALL-E `call.id` after `run-batch`. HUD shows last-8.
  final String? runId;

  CollectionsCallProgressRow copyWith({
    CollectionsCallRowStatus? status,
    String? runId,
  }) {
    return CollectionsCallProgressRow(
      contactId: contactId,
      status: status ?? this.status,
      runId: runId ?? this.runId,
    );
  }

  @override
  List<Object?> get props => [contactId, status, runId];
}

/// Device-side call progress from server per-row results (no fake spinner).
class CollectionsCallProgress extends Equatable {
  /// Creates call progress.
  const CollectionsCallProgress({
    required this.results,
  });

  /// Ordered per-recipient results.
  final List<CollectionsCallProgressRow> results;

  /// Total recipients in this batch.
  int get total => results.length;

  /// Status of the last row in the batch (drives the desk status word).
  CollectionsCallRowStatus? get latestRowStatus =>
      results.isEmpty ? null : results.last.status;

  /// Count of rows no longer `planned` — drives "Calling i of N".
  int get callingIndex {
    var started = 0;
    for (final row in results) {
      if (row.status != CollectionsCallRowStatus.planned) {
        started += 1;
      }
    }
    return started;
  }

  CollectionsCallProgress copyWith({
    List<CollectionsCallProgressRow>? results,
  }) {
    return CollectionsCallProgress(
      results: results ?? this.results,
    );
  }

  @override
  List<Object?> get props => [results];
}
