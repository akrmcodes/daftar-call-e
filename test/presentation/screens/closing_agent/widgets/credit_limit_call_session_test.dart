import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/credit_limit_call_resume_chip.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/credit_limit_call_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CollectionsDeskRow sampleRow() {
    return const CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: 'us',
        name: 'Ahmed',
        phone: '+15555550100',
        email: 'us@example.com',
        ledgerId: 'ledger',
        netBalance: -1500,
        currencyCode: 'USD',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
        rail: OutreachRail.both,
      ),
      body: 'Hello',
      toneBand: ReminderToneBand.reminder,
      attachPdf: false,
      callTask: 'Please pay your balance.',
    );
  }

  ProviderContainer seededContainer({
    required ClosingAgentState agentState,
  }) {
    final container = ProviderContainer();
    final notifier = container.read(closingAgentControllerProvider.notifier);
    notifier.state = agentState;
    return container;
  }

  Widget harness(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('session shows progress then Done on terminal', (tester) async {
    final live = ClosingAgentState(
      phase: ClosingAgentPhase.ritualDesk,
      callBatchTrigger: CallBatchTrigger.creditLimit,
      callConsented: true,
      deskRows: [sampleRow()],
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'us',
            status: CollectionsCallRowStatus.ringing,
          ),
        ],
      ),
    );
    final container = seededContainer(agentState: live);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      harness(container, const CreditLimitCallSession(paddingBottom: 24)),
    );

    expect(find.text('Call in progress'), findsWidgets);
    expect(find.text('Ahmed'), findsOneWidget);
    expect(find.text('Done'), findsNothing);

    final notifier = container.read(closingAgentControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'us',
            status: CollectionsCallRowStatus.completed,
            runId: 'run-abcdef12',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Call summary'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(
      container.read(closingAgentControllerProvider).phase,
      ClosingAgentPhase.idle,
    );
  });

  testWidgets('resume chip appears when session active', (tester) async {
    final active = ClosingAgentState(
      phase: ClosingAgentPhase.ritualDesk,
      callBatchTrigger: CallBatchTrigger.creditLimit,
      deskRows: [sampleRow()],
      callProgress: const CollectionsCallProgress(
        results: [
          CollectionsCallProgressRow(
            contactId: 'us',
            status: CollectionsCallRowStatus.planned,
          ),
        ],
      ),
    );
    final container = seededContainer(agentState: active);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      harness(container, const CreditLimitCallResumeChip()),
    );

    expect(find.text('Call in progress'), findsOneWidget);
  });

  testWidgets('resume chip hidden for other contact', (tester) async {
    final active = ClosingAgentState(
      phase: ClosingAgentPhase.ritualDesk,
      callBatchTrigger: CallBatchTrigger.creditLimit,
      deskRows: [sampleRow()],
    );
    final container = seededContainer(agentState: active);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      harness(
        container,
        const CreditLimitCallResumeChip(contactId: 'other'),
      ),
    );

    expect(find.text('Call in progress'), findsNothing);
  });
}
