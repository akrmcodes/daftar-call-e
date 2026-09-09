import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_report_status.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:equatable/equatable.dart';

/// One contact on the sealed daily call report.
class CollectionsCallReportRow extends Equatable {
  /// Creates a report row.
  const CollectionsCallReportRow({
    required this.contactId,
    required this.name,
    required this.status,
    this.outcome,
    this.runId,
    this.promisedAmountMinor,
    this.promisedCurrency,
    this.promisedDate,
  });

  /// Drift contact id.
  final String contactId;

  /// Display name from the shortlist.
  final String name;

  /// Report vocabulary (includes skipped / callUnavailable).
  final CollectionsCallReportStatus status;

  /// J.9 structured outcome when the call was terminal.
  final CallRunOutcome? outcome;

  /// CALL-E `call.id`. HUD / report show last-8.
  final String? runId;

  /// Integer minor units when [hasDisplayPromise] is true.
  final int? promisedAmountMinor;

  /// ISO currency for [promisedAmountMinor].
  final String? promisedCurrency;

  /// Merchant calendar day `YYYY-MM-DD`.
  final String? promisedDate;

  /// True when a promised integer amount and calendar day may be shown.
  bool get hasDisplayPromise {
    if (outcome != CallRunOutcome.promised) {
      return false;
    }
    final amount = promisedAmountMinor;
    final currency = promisedCurrency?.trim() ?? '';
    final date = promisedDate?.trim() ?? '';
    return amount != null &&
        currency.isNotEmpty &&
        PromisedCalendarDay.isValid(date);
  }

  @override
  List<Object?> get props => [
    contactId,
    name,
    status,
    outcome,
    runId,
    promisedAmountMinor,
    promisedCurrency,
    promisedDate,
  ];
}

/// Device-owned call summary for the hero closing report.
class CollectionsCallReport extends Equatable {
  /// Creates a call report.
  const CollectionsCallReport({
    required this.rows,
  });

  /// Builds the sealed report from live progress plus dual-rail shortlist.
  factory CollectionsCallReport.fromProgress({
    required CollectionsCallProgress? progress,
    required List<CollectionsCandidate> shortlist,
  }) {
    final names = <String, String>{
      for (final candidate in shortlist) candidate.contactId: candidate.name,
    };
    final seen = <String>{};
    final rows = <CollectionsCallReportRow>[];

    for (final row
        in progress?.results ?? const <CollectionsCallProgressRow>[]) {
      seen.add(row.contactId);
      rows.add(
        CollectionsCallReportRow(
          contactId: row.contactId,
          name: names[row.contactId] ?? row.contactId,
          status: _statusFromProgress(row.status),
          outcome: row.outcome,
          runId: row.runId,
          promisedAmountMinor: row.promisedAmountMinor,
          promisedCurrency: row.promisedCurrency,
          promisedDate: row.promisedDate,
        ),
      );
    }

    for (final candidate in shortlist) {
      if (seen.contains(candidate.contactId)) {
        continue;
      }
      if (candidate.rail != OutreachRail.callUnavailable) {
        continue;
      }
      seen.add(candidate.contactId);
      rows.add(
        CollectionsCallReportRow(
          contactId: candidate.contactId,
          name: candidate.name,
          status: CollectionsCallReportStatus.callUnavailable,
        ),
      );
    }

    for (final candidate in shortlist) {
      if (seen.contains(candidate.contactId)) {
        continue;
      }
      if (candidate.rail != OutreachRail.call &&
          candidate.rail != OutreachRail.both) {
        continue;
      }
      seen.add(candidate.contactId);
      rows.add(
        CollectionsCallReportRow(
          contactId: candidate.contactId,
          name: candidate.name,
          status: CollectionsCallReportStatus.skipped,
        ),
      );
    }

    return CollectionsCallReport(
      rows: List<CollectionsCallReportRow>.unmodifiable(rows),
    );
  }

  /// Ordered contacts for the visual report.
  final List<CollectionsCallReportRow> rows;

  /// True when the report section should render.
  bool get isNotEmpty => rows.isNotEmpty;

  static CollectionsCallReportStatus _statusFromProgress(
    CollectionsCallRowStatus status,
  ) {
    return switch (status) {
      CollectionsCallRowStatus.planned => CollectionsCallReportStatus.planned,
      CollectionsCallRowStatus.ringing => CollectionsCallReportStatus.ringing,
      CollectionsCallRowStatus.completed =>
        CollectionsCallReportStatus.completed,
      CollectionsCallRowStatus.failed => CollectionsCallReportStatus.failed,
    };
  }

  @override
  List<Object?> get props => [rows];
}
