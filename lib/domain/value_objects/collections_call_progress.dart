import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:equatable/equatable.dart';

/// One row in the call progress rail.
class CollectionsCallProgressRow extends Equatable {
  /// Creates a progress row.
  const CollectionsCallProgressRow({
    required this.contactId,
    required this.status,
  });

  /// Drift contact id.
  final String contactId;

  /// Current CALL-E row status.
  final CollectionsCallRowStatus status;

  CollectionsCallProgressRow copyWith({
    CollectionsCallRowStatus? status,
  }) {
    return CollectionsCallProgressRow(
      contactId: contactId,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [contactId, status];
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
