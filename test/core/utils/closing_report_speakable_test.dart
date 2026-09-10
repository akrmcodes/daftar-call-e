import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/closing_report_speakable.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/collections_call_report_status.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_call_report.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations ar;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    ar = lookupAppLocalizations(const Locale('ar'));
  });

  ClosingRitualResult result({
    ClosingBackupStatus backup = ClosingBackupStatus.uploaded,
    int debts = 3,
    int payments = 2,
    int overdue = 0,
    CollectionsQueueMetrics? queue,
  }) {
    return ClosingRitualResult(
      summary: ClosingDaySummary(
        localDay: '2026-08-15',
        debtCount: debts,
        paymentCount: payments,
        totals: const [],
      ),
      backupStatus: backup,
      shortlist: const [],
      overdueTotal: overdue == 0 ? null : overdue,
      queueMetrics: queue,
    );
  }

  test('books line names today and ends with the close', () {
    final spoken = closingReportSpeakable(l10n: en, result: result());
    expect(spoken, contains('Day closed'));
    expect(spoken, contains('Today you recorded 3 debts and 2 payments'));
    expect(spoken, contains('Google Drive'));
    expect(spoken, contains('safe'));
    expect(spoken, isNot(contains('overdue')));
    expect(spoken, endsWith("That's the close for today"));
  });

  test('queued does not claim Drive already saved', () {
    final spoken = closingReportSpeakable(
      l10n: en,
      result: result(backup: ClosingBackupStatus.queued),
    );
    expect(spoken, contains('back online'));
    expect(spoken, isNot(contains('on Google Drive')));
    expect(spoken, isNot(contains('safe')));
  });

  test('grantRequired does not claim Drive already saved', () {
    final spoken = closingReportSpeakable(
      l10n: en,
      result: result(backup: ClosingBackupStatus.grantRequired),
    );
    expect(spoken, contains('Approve Google Drive access'));
    expect(spoken, isNot(contains('on Google Drive')));
    expect(spoken, isNot(contains('safe')));
  });

  test('unsigned and failed are honest', () {
    final unsigned = closingReportSpeakable(
      l10n: en,
      result: result(backup: ClosingBackupStatus.skippedUnsigned),
    );
    expect(unsigned, contains('Sign in'));
    expect(unsigned, isNot(contains('safe')));

    final failed = closingReportSpeakable(
      l10n: en,
      result: result(backup: ClosingBackupStatus.failed),
    );
    expect(failed, contains('another try'));
    expect(failed, isNot(contains('safe')));
  });

  test('queue metrics speak prepared sent failed not overdue ready', () {
    final spoken = closingReportSpeakable(
      l10n: en,
      result: result(
        overdue: 7,
        queue: const CollectionsQueueMetrics(
          prepared: 7,
          opened: 0,
          skipped: 0,
        ),
      ),
    );
    expect(spoken, contains('7 prepared, 0 sent, 0 failed'));
    expect(spoken, isNot(contains('overdue accounts are ready')));
    expect(spoken, isNot(contains('overdue accounts remain')));
    expect(spoken, endsWith("That's the close for today"));
  });

  test('without metrics overdue remain is spoken', () {
    final spoken = closingReportSpeakable(
      l10n: en,
      result: result(overdue: 5),
    );
    expect(spoken, contains('5 overdue accounts remain'));
    expect(spoken, isNot(contains('prepared')));
  });

  test('call report is visual only and is not spoken', () {
    const callReport = CollectionsCallReport(
      rows: [
        CollectionsCallReportRow(
          contactId: 'us',
          name: 'Mohamed',
          status: CollectionsCallReportStatus.completed,
          outcome: CallRunOutcome.promised,
          runId: 'call_GfN-BQcGMORm2NkgSfxdIw',
          promisedAmountMinor: 50000,
          promisedCurrency: 'USD',
          promisedDate: '2026-09-15',
        ),
      ],
    );
    final spoken = closingReportSpeakable(
      l10n: en,
      result: const ClosingRitualResult(
        summary: ClosingDaySummary(
          localDay: '2026-08-15',
          debtCount: 3,
          paymentCount: 2,
          totals: [],
        ),
        backupStatus: ClosingBackupStatus.uploaded,
        shortlist: [],
        callReport: callReport,
      ),
    );
    expect(spoken, isNot(contains('Mohamed')));
    expect(spoken, isNot(contains('500')));
    expect(spoken, isNot(contains('2026-09-15')));
    expect(spoken, isNot(contains('Call report')));
    expect(spoken, contains('Today you recorded 3 debts and 2 payments'));
  });

  test('Arabic grant speech has no Latin Drive', () {
    final spoken = closingReportSpeakable(
      l10n: ar,
      result: result(backup: ClosingBackupStatus.grantRequired),
    );
    expect(spoken, isNot(contains('Drive')));
    expect(spoken, contains('درايف'));
  });
}
