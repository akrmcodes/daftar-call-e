import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_report_status.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_call_report.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

CollectionsCandidate _candidate({
  required String id,
  required String name,
  required OutreachRail rail,
}) {
  return CollectionsCandidate(
    contactId: id,
    name: name,
    email: '$id@example.com',
    phone: '+15555550100',
    ledgerId: 'ledger',
    netBalance: -100,
    currencyCode: 'USD',
    ageDays: 12,
    toneBand: ReminderToneBand.reminder,
    rail: rail,
  );
}

void main() {
  test(
    'fromProgress maps promised US, YE unavailable, and skipped call-set',
    () {
      final shortlist = [
        _candidate(id: 'us', name: 'Mohamed', rail: OutreachRail.both),
        _candidate(
          id: 'ye',
          name: 'Ahmed',
          rail: OutreachRail.callUnavailable,
        ),
        _candidate(id: 'skip', name: 'Nadia', rail: OutreachRail.call),
        _candidate(id: 'email', name: 'Salem', rail: OutreachRail.email),
      ];
      const progress = CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'us',
            status: CollectionsCallRowStatus.completed,
            runId: 'call_GfN-BQcGMORm2NkgSfxdIw',
            outcome: CallRunOutcome.promised,
            promisedAmountMinor: 50000,
            promisedCurrency: 'USD',
            promisedDate: '2026-09-15',
          ),
        ],
      );

      final report = CollectionsCallReport.fromProgress(
        progress: progress,
        shortlist: shortlist,
      );

      expect(report.rows, hasLength(3));
      expect(report.rows[0].name, 'Mohamed');
      expect(report.rows[0].status, CollectionsCallReportStatus.completed);
      expect(report.rows[0].hasDisplayPromise, isTrue);
      expect(report.rows[0].promisedAmountMinor, 50000);
      expect(report.rows[0].promisedDate, '2026-09-15');
      expect(report.rows[1].contactId, 'ye');
      expect(
        report.rows[1].status,
        CollectionsCallReportStatus.callUnavailable,
      );
      expect(report.rows[2].contactId, 'skip');
      expect(report.rows[2].status, CollectionsCallReportStatus.skipped);
    },
  );

  test('fromProgress is empty without progress or call-set rows', () {
    final report = CollectionsCallReport.fromProgress(
      progress: null,
      shortlist: [
        _candidate(id: 'e', name: 'Email', rail: OutreachRail.email),
      ],
    );
    expect(report.isNotEmpty, isFalse);
  });

  test(
    'hasDisplayPromise requires promised outcome and valid calendar day',
    () {
      const row = CollectionsCallReportRow(
        contactId: 'us',
        name: 'Mohamed',
        status: CollectionsCallReportStatus.completed,
        outcome: CallRunOutcome.promised,
        promisedAmountMinor: 50000,
        promisedCurrency: 'USD',
        promisedDate: 'not-a-day',
      );
      expect(row.hasDisplayPromise, isFalse);
    },
  );
}
