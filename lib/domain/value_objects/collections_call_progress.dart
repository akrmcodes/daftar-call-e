import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:equatable/equatable.dart';

/// One row in the call progress rail.
class CollectionsCallProgressRow extends Equatable {
  /// Creates a progress row.
  const CollectionsCallProgressRow({
    required this.contactId,
    required this.status,
    this.runId,
    this.outcome,
    this.retryCount = 0,
    this.promisedAmountMinor,
    this.promisedCurrency,
    this.promisedDate,
  });

  /// Drift contact id.
  final String contactId;

  /// Current CALL-E row status.
  final CollectionsCallRowStatus status;

  /// CALL-E `call.id` after `run-batch`. HUD shows last-8.
  final String? runId;

  /// J.9 structured outcome when terminal.
  final CallRunOutcome? outcome;

  /// 0 = first create; 1 = one no-answer/voicemail retry.
  final int retryCount;

  /// Integer minor units from a terminal promised result.
  final int? promisedAmountMinor;

  /// ISO currency for [promisedAmountMinor].
  final String? promisedCurrency;

  /// Merchant calendar day `YYYY-MM-DD`.
  final String? promisedDate;

  CollectionsCallProgressRow copyWith({
    CollectionsCallRowStatus? status,
    String? runId,
    CallRunOutcome? outcome,
    int? retryCount,
    int? promisedAmountMinor,
    String? promisedCurrency,
    String? promisedDate,
  }) {
    return CollectionsCallProgressRow(
      contactId: contactId,
      status: status ?? this.status,
      runId: runId ?? this.runId,
      outcome: outcome ?? this.outcome,
      retryCount: retryCount ?? this.retryCount,
      promisedAmountMinor: promisedAmountMinor ?? this.promisedAmountMinor,
      promisedCurrency: promisedCurrency ?? this.promisedCurrency,
      promisedDate: promisedDate ?? this.promisedDate,
    );
  }

  @override
  List<Object?> get props => [
    contactId,
    status,
    runId,
    outcome,
    retryCount,
    promisedAmountMinor,
    promisedCurrency,
    promisedDate,
  ];
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

  /// True when every row is terminal (`completed` or `failed`).
  bool get isTerminal {
    if (results.isEmpty) {
      return false;
    }
    return results.every(
      (row) =>
          row.status == CollectionsCallRowStatus.completed ||
          row.status == CollectionsCallRowStatus.failed,
    );
  }

  /// Last row with a non-empty [CollectionsCallProgressRow.runId].
  CollectionsCallProgressRow? get lastRowWithRunId {
    CollectionsCallProgressRow? last;
    for (final row in results) {
      final trimmed = row.runId?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        last = row;
      }
    }
    return last;
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
