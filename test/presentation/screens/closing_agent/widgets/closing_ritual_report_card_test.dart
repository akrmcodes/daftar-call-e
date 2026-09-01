import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {};
  });

  tearDown(() {
    DeviceTts.debugSpeakOverride = null;
    DeviceTts.debugStopOverride = null;
    DeviceTts.debugReset();
    AgentSpeech.debugReset();
  });

  testWidgets('empty overdue report shows nothing to collect', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ClosingRitualReportCard(
          ttsMuted: true,
          result: ClosingRitualResult(
            summary: ClosingDaySummary(
              localDay: '2026-08-15',
              debtCount: 0,
              paymentCount: 0,
              totals: [],
            ),
            backupStatus: ClosingBackupStatus.uploaded,
            shortlist: [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DaftarBrandMark), findsOneWidget);
    expect(find.text('Day closed'), findsOneWidget);
    expect(find.text('2026-08-15'), findsOneWidget);
    expect(find.text('Nothing to collect'), findsOneWidget);
    expect(find.text('Backup saved to Drive'), findsOneWidget);
    expect(find.text('0 prepared'), findsNothing);
  });

  testWidgets('queue metrics show prepared sent failed opened skipped', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ClosingRitualReportCard(
          ttsMuted: true,
          result: ClosingRitualResult(
            summary: ClosingDaySummary(
              localDay: '2026-08-15',
              debtCount: 1,
              paymentCount: 0,
              totals: [],
            ),
            backupStatus: ClosingBackupStatus.uploaded,
            shortlist: [],
            reminderPolicy: ClosingReminderPolicy.all,
            queueMetrics: CollectionsQueueMetrics(
              prepared: 5,
              opened: 3,
              skipped: 2,
            ),
            overdueTotal: 12,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('12 overdue'), findsWidgets);
    expect(find.text('5 prepared'), findsOneWidget);
    expect(find.text('0 sent'), findsOneWidget);
    expect(find.text('0 failed'), findsOneWidget);
    expect(find.text('3 opened'), findsOneWidget);
    expect(find.text('2 skipped'), findsOneWidget);
  });

  testWidgets('unsigned Drive backup is not sign-in failed copy', (
    tester,
  ) async {
    var signIns = 0;
    await tester.pumpWidget(
      _wrap(
        ClosingRitualReportCard(
          ttsMuted: true,
          result: const ClosingRitualResult(
            summary: ClosingDaySummary(
              localDay: '2026-08-15',
              debtCount: 0,
              paymentCount: 0,
              totals: [],
            ),
            backupStatus: ClosingBackupStatus.skippedUnsigned,
            shortlist: [],
          ),
          onSignInToDrive: () => signIns++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Google sign-in failed'), findsNothing);
    expect(find.textContaining('tonight'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    expect(signIns, 1);
  });

  testWidgets('grant-required Drive backup shows grant copy not offline', (
    tester,
  ) async {
    var grants = 0;
    await tester.pumpWidget(
      _wrap(
        ClosingRitualReportCard(
          ttsMuted: true,
          result: const ClosingRitualResult(
            summary: ClosingDaySummary(
              localDay: '2026-08-15',
              debtCount: 0,
              paymentCount: 0,
              totals: [],
            ),
            backupStatus: ClosingBackupStatus.grantRequired,
            shortlist: [],
          ),
          onGrantDrive: () => grants++,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('Drive permission was not granted'),
      findsOneWidget,
    );
    expect(find.textContaining('No internet connection'), findsNothing);
    expect(find.text('Complete now'), findsOneWidget);

    await tester.tap(find.text('Complete now'));
    await tester.pump();
    expect(grants, 1);
  });

  testWidgets('ceremony with motion completes without throw', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ClosingRitualReportCard(
            ttsMuted: true,
            result: ClosingRitualResult(
              summary: ClosingDaySummary(
                localDay: '2026-08-15',
                debtCount: 0,
                paymentCount: 0,
                totals: [],
              ),
              backupStatus: ClosingBackupStatus.uploaded,
              shortlist: [],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(DaftarBrandMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
