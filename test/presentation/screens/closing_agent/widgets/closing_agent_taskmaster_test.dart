import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_task_id.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plan review shows device tasks and Confirm CTAs', (
    tester,
  ) async {
    var sent = false;
    var withoutSending = false;

    tester.view
      ..physicalSize = const Size(400, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.planReview,
          localDay: '2026-08-24',
          showActions: true,
          onConfirmAndSend: () => sent = true,
          onConfirmWithoutSending: () => withoutSending = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text("Today's closing plan"), findsOneWidget);
    expect(find.text('Reconcile ledger'), findsOneWidget);
    expect(find.text('Present the day seal'), findsOneWidget);
    expect(find.text('Start close'), findsOneWidget);
    expect(find.text('Start close without outreach'), findsOneWidget);
    expect(find.text('Confirm & Send Statements'), findsNothing);
    expect(find.text('Approve plan'), findsNothing);
    expect(find.text(ClosingTaskOrder.ordered.length.toString()), findsNothing);

    await tester.ensureVisible(find.text('Start close'));
    await tester.tap(find.text('Start close'));
    await tester.pump();
    expect(sent, isTrue);
    expect(withoutSending, isFalse);

    await tester.ensureVisible(find.text('Start close without outreach'));
    await tester.tap(find.text('Start close without outreach'));
    await tester.pump();
    expect(withoutSending, isTrue);
  });

  testWidgets('plan review shows Skip and calls onSkip', (tester) async {
    var skipped = false;

    await tester.pumpWidget(
      _wrap(
        ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.planReview,
          localDay: '2026-08-24',
          showActions: true,
          onSkip: () => skipped = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(skipped, isTrue);
  });

  testWidgets('execution marks done tasks with check icons', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.executing,
          localDay: '2026-08-24',
          tasksDone: {
            ClosingTaskId.bindLedger,
            ClosingTaskId.collectDebts,
          },
          taskCurrent: ClosingTaskId.collectPayments,
          summary: ClosingDaySummary(
            localDay: '2026-08-24',
            debtCount: 3,
            paymentCount: 1,
            totals: [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.text("Collect today's payments"), findsOneWidget);
    expect(find.text('1 payments today'), findsOneWidget);
  });

  testWidgets('RTL plan review renders Arabic task titles', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.planReview,
          localDay: '2026-08-24',
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('خطة إقفال اليوم'), findsOneWidget);
    expect(find.text('مطابقة القيود'), findsOneWidget);
  });

  testWidgets('sealed rail shows sealed count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ClosingAgentTaskmaster(
              mode: ClosingAgentTaskmasterMode.sealed,
              localDay: '2026-08-24',
              tasksDone: Set<ClosingTaskId>.from(ClosingTaskOrder.ordered),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('13 tasks sealed'), findsOneWidget);
  });

  testWidgets('compact desk task is Open collections desk', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ClosingAgentTaskmaster(
          mode: ClosingAgentTaskmasterMode.compact,
          localDay: '2026-08-24',
          taskCurrent: ClosingTaskId.openCollectionsDesk,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Open collections desk'), findsOneWidget);
    expect(find.text('Dispatch collection emails'), findsNothing);
  });
}
