import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:equatable/equatable.dart';

/// Device-owned close-the-day snapshot after plan confirm.
class ClosingRitualResult extends Equatable {
  /// Creates a ritual result.
  const ClosingRitualResult({
    required this.summary,
    required this.backupStatus,
    required this.shortlist,
    this.reminderPolicy = ClosingReminderPolicy.none,
    this.pdfPolicy = ClosingPdfPolicy.none,
    this.needsHuman = false,
    this.queueMetrics,
    this.overdueTotal,
  });

  /// Drift `localDay` counts and integer totals.
  final ClosingDaySummary summary;

  /// Drive upload / queue outcome.
  final ClosingBackupStatus backupStatus;

  /// Full ranked overdue shortlist with dual-rail assignment.
  final List<CollectionsCandidate> shortlist;

  /// Merchant reminder choice. Defaults to none until prompted.
  final ClosingReminderPolicy reminderPolicy;

  /// Merchant PDF policy. Defaults to none until prompted.
  final ClosingPdfPolicy pdfPolicy;

  /// True when backup queued, failed, or unsigned.
  final bool needsHuman;

  /// Desk/queue counts after the merchant leaves the Desk (null if Desk skipped).
  final CollectionsQueueMetrics? queueMetrics;

  /// Original shortlist length. Used after process-death restore.
  final int? overdueTotal;

  /// Overdue line for the report (restored queues may have a truncated shortlist).
  int get overdueCount => overdueTotal ?? shortlist.length;

  /// Email-rail rows in rank order (send set before merchant policy cap).
  List<CollectionsCandidate> get emailRailShortlist => [
        for (final row in shortlist)
          if (row.rail == OutreachRail.email ||
              row.rail == OutreachRail.both ||
              row.rail == OutreachRail.callUnavailable)
            row,
      ];

  /// CALL-E call set in rank order.
  List<CollectionsCandidate> get callSet => [
        for (final row in shortlist)
          if (row.rail == OutreachRail.call || row.rail == OutreachRail.both)
            row,
      ];

  /// Contacts that will receive reminder drafts (4.2).
  List<CollectionsCandidate> get reminderSet {
    final emailRows = emailRailShortlist;
    switch (reminderPolicy) {
      case ClosingReminderPolicy.none:
        return const [];
      case ClosingReminderPolicy.top5:
        return emailRows
            .take(ClosingAgentConstants.statementSetSize)
            .toList(growable: false);
      case ClosingReminderPolicy.all:
        return emailRows
            .take(ClosingAgentConstants.maxEmailRecipients)
            .toList(growable: false);
    }
  }

  /// Contacts flagged for statement PDFs (4.2). Not generated here.
  List<CollectionsCandidate> get pdfContacts {
    final set = reminderSet;
    switch (pdfPolicy) {
      case ClosingPdfPolicy.none:
        return const [];
      case ClosingPdfPolicy.selective:
        return [
          for (final row in set)
            if (row.ageDays >= 30 ||
                row.toneBand == ReminderToneBand.firm)
              row,
        ];
      case ClosingPdfPolicy.allInSet:
        return set;
      case ClosingPdfPolicy.rankedTop5:
        return set
            .take(ClosingAgentConstants.statementSetSize)
            .toList(growable: false);
    }
  }

  /// Applies reminder policy. [ClosingReminderPolicy.none] clears PDF policy.
  ClosingRitualResult withReminderPolicy(ClosingReminderPolicy policy) {
    return ClosingRitualResult(
      summary: summary,
      backupStatus: backupStatus,
      shortlist: shortlist,
      reminderPolicy: policy,
      pdfPolicy: policy == ClosingReminderPolicy.none
          ? ClosingPdfPolicy.none
          : pdfPolicy,
      needsHuman: needsHuman,
      queueMetrics: queueMetrics,
      overdueTotal: overdueTotal,
    );
  }

  /// Applies PDF policy after Yes / Top 5.
  ClosingRitualResult withPdfPolicy(ClosingPdfPolicy policy) {
    return ClosingRitualResult(
      summary: summary,
      backupStatus: backupStatus,
      shortlist: shortlist,
      reminderPolicy: reminderPolicy,
      pdfPolicy: policy,
      needsHuman: needsHuman,
      queueMetrics: queueMetrics,
      overdueTotal: overdueTotal,
    );
  }

  /// Attaches Hybrid E queue metrics for the hero report.
  ClosingRitualResult withQueueMetrics(CollectionsQueueMetrics metrics) {
    return ClosingRitualResult(
      summary: summary,
      backupStatus: backupStatus,
      shortlist: shortlist,
      reminderPolicy: reminderPolicy,
      pdfPolicy: pdfPolicy,
      needsHuman: needsHuman,
      queueMetrics: metrics,
      overdueTotal: overdueTotal ?? shortlist.length,
    );
  }

  @override
  List<Object?> get props => [
    summary,
    backupStatus,
    shortlist,
    reminderPolicy,
    pdfPolicy,
    needsHuman,
    queueMetrics,
    overdueTotal,
  ];
}
