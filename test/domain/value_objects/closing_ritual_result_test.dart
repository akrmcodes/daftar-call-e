import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_call_report.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CollectionsCandidate row({
    required String id,
    required int ageDays,
    required ReminderToneBand tone,
  }) {
    return CollectionsCandidate(
      contactId: id,
      name: id,
      phone: '+96770000000$id',
      email: '$id@example.com',
      ledgerId: 'ledger',
      netBalance: -100,
      currencyCode: 'YER',
      ageDays: ageDays,
      toneBand: tone,
      rail: OutreachRail.email,
    );
  }

  final shortlist = [
    for (var i = 0; i < 7; i++)
      row(
        id: '$i',
        ageDays: i < 2 ? 40 : 3,
        tone: i < 2 ? ReminderToneBand.firm : ReminderToneBand.friendly,
      ),
  ];

  const summary = ClosingDaySummary(
    localDay: '2026-08-15',
    debtCount: 0,
    paymentCount: 0,
    totals: [],
  );

  ClosingRitualResult base() {
    return ClosingRitualResult(
      summary: summary,
      backupStatus: ClosingBackupStatus.uploaded,
      shortlist: shortlist,
    );
  }

  test('top5 caps reminder set at 5', () {
    final result = base().withReminderPolicy(ClosingReminderPolicy.top5);
    expect(result.reminderSet, hasLength(5));
    expect(result.reminderSet.map((e) => e.contactId), [
      '0',
      '1',
      '2',
      '3',
      '4',
    ]);
  });

  test('none reminder set is empty and clears PDF policy', () {
    final result = base()
        .withReminderPolicy(ClosingReminderPolicy.all)
        .withPdfPolicy(ClosingPdfPolicy.allInSet)
        .withReminderPolicy(ClosingReminderPolicy.none);
    expect(result.reminderSet, isEmpty);
    expect(result.pdfPolicy, ClosingPdfPolicy.none);
    expect(result.pdfContacts, isEmpty);
  });

  test('overdueCount prefers overdueTotal after a truncated restore', () {
    final result = ClosingRitualResult(
      summary: summary,
      backupStatus: ClosingBackupStatus.uploaded,
      shortlist: shortlist.take(5).toList(),
      reminderPolicy: ClosingReminderPolicy.top5,
      overdueTotal: 7,
    );
    expect(result.overdueCount, 7);
    expect(result.reminderSet, hasLength(5));
  });

  test('selective PDFs are firm or ageDays >= 30 in the reminder set', () {
    final result = base()
        .withReminderPolicy(ClosingReminderPolicy.all)
        .withPdfPolicy(ClosingPdfPolicy.selective);
    expect(result.pdfContacts.map((e) => e.contactId), ['0', '1']);
  });

  test('selective PDF still includes ageDays >= 30 after reminder cap', () {
    const capped = CollectionsCandidate(
      contactId: 'capped',
      name: 'capped',
      phone: '+967700000009',
      email: 'capped@example.com',
      ledgerId: 'ledger',
      netBalance: -100,
      currencyCode: 'YER',
      ageDays: 40,
      toneBand: ReminderToneBand.reminder,
      rail: OutreachRail.email,
    );
    const result = ClosingRitualResult(
      summary: summary,
      backupStatus: ClosingBackupStatus.uploaded,
      shortlist: [capped],
      reminderPolicy: ClosingReminderPolicy.all,
      pdfPolicy: ClosingPdfPolicy.selective,
    );
    expect(result.pdfContacts.single.contactId, 'capped');
  });

  test('all reminder policy caps send set at 20', () {
    final longList = [
      for (var i = 0; i < 25; i++)
        row(
          id: '$i',
          ageDays: 12,
          tone: ReminderToneBand.reminder,
        ),
    ];
    final result = ClosingRitualResult(
      summary: summary,
      backupStatus: ClosingBackupStatus.uploaded,
      shortlist: longList,
    ).withReminderPolicy(ClosingReminderPolicy.all);
    expect(result.reminderSet, hasLength(20));
  });

  test('rankedTop5 PDFs are first five of the send set', () {
    final result = base()
        .withReminderPolicy(ClosingReminderPolicy.all)
        .withPdfPolicy(ClosingPdfPolicy.rankedTop5);
    expect(result.reminderSet, hasLength(7));
    expect(result.pdfContacts, hasLength(5));
    expect(result.pdfContacts.map((e) => e.contactId), [
      '0',
      '1',
      '2',
      '3',
      '4',
    ]);
  });

  test('withCallReport attaches rows and survives queue metrics', () {
    final report = CollectionsCallReport.fromProgress(
      progress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: '0',
            status: CollectionsCallRowStatus.completed,
          ),
        ],
      ),
      shortlist: shortlist,
    );
    final result = base()
        .withCallReport(report)
        .withQueueMetrics(
          const CollectionsQueueMetrics(prepared: 1, opened: 0, skipped: 0),
        );
    expect(result.callReport?.rows, hasLength(1));
    expect(result.queueMetrics?.prepared, 1);
  });
}
