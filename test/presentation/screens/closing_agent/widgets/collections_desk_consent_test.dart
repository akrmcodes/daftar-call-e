import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/collections_call_task_composer.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_consent_card.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_panel.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CollectionsDeskRow usRow({bool attachPdf = false}) {
    final task = CollectionsCallTaskComposer.compose(
      locale: 'en',
      storeName: 'Daftar',
      contactName: 'US Contact',
      amountMinor: 1500,
      currencyCode: 'USD',
    );
    return CollectionsDeskRow(
      candidate: const CollectionsCandidate(
        contactId: 'us',
        name: 'US Contact',
        phone: '+15555550100',
        email: 'us@example.com',
        ledgerId: 'ledger',
        netBalance: -1500,
        currencyCode: 'USD',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
        rail: OutreachRail.both,
      ),
      body: 'Hello US Contact',
      toneBand: ReminderToneBand.reminder,
      attachPdf: attachPdf,
      callTask: task.task,
    );
  }

  CollectionsDeskRow yeRow() {
    return const CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: 'ye',
        name: 'Yemen',
        phone: '0771234567',
        email: 'ye@example.com',
        ledgerId: 'ledger',
        netBalance: -1000,
        currencyCode: 'YER',
        ageDays: 20,
        toneBand: ReminderToneBand.firm,
        rail: OutreachRail.callUnavailable,
      ),
      body: 'Hello Yemen',
      toneBand: ReminderToneBand.firm,
      attachPdf: false,
    );
  }

  Widget consentHost({
    required int callCount,
    required int emailCount,
    String callLeadName = 'Mohamed',
    int pdfCount = 0,
    int textCount = 0,
    bool callConsented = false,
    bool sendOutreachEnabled = true,
    CollectionsCallProgress? callProgress,
    void Function({required bool call, required bool send})? onCommit,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CollectionsDeskConsentCard(
          callCount: callCount,
          emailCount: emailCount,
          callLeadName: callLeadName,
          pdfCount: pdfCount,
          textCount: textCount,
          callConsented: callConsented,
          sendOutreachEnabled: sendOutreachEnabled,
          busy: false,
          isDispatching: false,
          callProgress: callProgress,
          onCommit: onCommit ?? ({required call, required send}) {},
        ),
      ),
    );
  }

  testWidgets('default both-on shows dual-rail commit CTA', (tester) async {
    await tester.pumpWidget(
      consentHost(
        callCount: 2,
        emailCount: 5,
        callLeadName: 'Mohamed',
        pdfCount: 5,
        textCount: 0,
      ),
    );

    expect(find.text('Voice calls'), findsOneWidget);
    expect(find.text('Email statements'), findsOneWidget);
    expect(find.textContaining('2 scheduled calls'), findsOneWidget);
    expect(find.textContaining('Mohamed'), findsOneWidget);
    expect(find.text('Confirm (2 calls + 5 statements)'), findsOneWidget);
    expect(find.text('A promise is not a payment'), findsNothing);
  });

  testWidgets('email ON shows PDF and text tiering', (tester) async {
    await tester.pumpWidget(
      consentHost(
        callCount: 1,
        emailCount: 7,
        pdfCount: 5,
        textCount: 2,
      ),
    );

    expect(find.text('7 statements'), findsOneWidget);
    expect(find.text('5 with PDF · 2 text only'), findsOneWidget);
  });

  testWidgets('toggle call off shows email-only CTA', (tester) async {
    await tester.pumpWidget(consentHost(callCount: 1, emailCount: 3));
    await tester.tap(find.text('Voice calls'));
    await tester.pumpAndSettle();

    expect(find.text('Send statements only (3 statements)'), findsOneWidget);
    expect(find.textContaining('Skipped — No outbound calls'), findsOneWidget);
  });

  testWidgets('both off shows seal CTA', (tester) async {
    await tester.pumpWidget(consentHost(callCount: 1, emailCount: 2));
    await tester.tap(find.text('Voice calls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Email statements'));
    await tester.pumpAndSettle();

    expect(find.text('Close day without outreach'), findsOneWidget);
  });

  testWidgets('commit passes chip selection', (tester) async {
    bool? committedCall;
    bool? committedSend;
    await tester.pumpWidget(
      consentHost(
        callCount: 1,
        emailCount: 2,
        onCommit: ({required call, required send}) {
          committedCall = call;
          committedSend = send;
        },
      ),
    );
    await tester.tap(find.text('Voice calls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send statements only (2 statements)'));
    await tester.pumpAndSettle();

    expect(committedCall, isFalse);
    expect(committedSend, isTrue);
  });

  testWidgets('YE row shows Cant call badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: yeRow(),
            isOpening: false,
            onSkip: () {},
            onCopy: () {},
            onOpen: () {},
            onTone: (_) {},
            onTogglePdf: () {},
          ),
        ),
      ),
    );

    expect(find.text("Can't call"), findsOneWidget);
  });

  testWidgets('C.3 preview matches composer', (tester) async {
    final row = usRow();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: row,
            isOpening: false,
            onSkip: () {},
            onCopy: () {},
            onOpen: () {},
            onTone: (_) {},
            onTogglePdf: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Call US Contact on behalf of'), findsOneWidget);
    expect(find.text(row.callTask), findsOneWidget);
  });

  testWidgets('progress shows Calling 1 of 3 from results', (tester) async {
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'a',
          status: CollectionsCallRowStatus.planned,
        ),
        CollectionsCallProgressRow(
          contactId: 'b',
          status: CollectionsCallRowStatus.planned,
        ),
        CollectionsCallProgressRow(
          contactId: 'c',
          status: CollectionsCallRowStatus.completed,
        ),
      ],
    );

    await tester.pumpWidget(
      consentHost(
        callCount: 3,
        emailCount: 0,
        callConsented: true,
        sendOutreachEnabled: false,
        callProgress: progress,
      ),
    );

    expect(find.text('Calling 1 of 3'), findsOneWidget);
  });

  testWidgets('SMTP desk shows rail card commit dock', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskPanel(
            rows: [usRow(), yeRow()],
            callCount: 1,
            emailCount: 2,
            callConsented: false,
            sendOutreachEnabled: true,
            startSendingIsPrimary: true,
            busyContactId: null,
            onCommitOutreach: ({required call, required send}) {},
            onSkip: (_) {},
            onCopy: (_) {},
            onOpen: (_) {},
            onTone: (_, _) {},
            onTogglePdf: (_) {},
            onStartSending: () {},
            onApproveAndSend: () {},
            onDone: () {},
          ),
        ),
      ),
    );

    expect(find.text('Confirm (1 call + 2 statements)'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
  });

  testWidgets('RTL smoke shows Arabic rail titles and CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 1,
            emailCount: 1,
            callLeadName: 'محمد',
            pdfCount: 1,
            textCount: 0,
            callConsented: false,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            onCommit: ({required call, required send}) {},
          ),
        ),
      ),
    );

    expect(find.text('مكالمات صوتية'), findsOneWidget);
    expect(find.textContaining('تأكيد'), findsOneWidget);
  });

  testWidgets('YE-only desk hides call card', (tester) async {
    await tester.pumpWidget(
      consentHost(
        callCount: 0,
        emailCount: 2,
        pdfCount: 0,
        textCount: 2,
      ),
    );

    expect(find.text('Voice calls'), findsNothing);
    expect(find.text('Email statements'), findsOneWidget);
    expect(find.text('Send statements only (2 statements)'), findsOneWidget);
  });

  testWidgets('after call consented email card remains for follow-up send', (
    tester,
  ) async {
    await tester.pumpWidget(
      consentHost(
        callCount: 1,
        emailCount: 2,
        callConsented: true,
      ),
    );

    expect(find.text('Voice calls'), findsNothing);
    expect(find.text('Email statements'), findsOneWidget);
    expect(find.text('Send statements only (2 statements)'), findsOneWidget);
  });

  testWidgets('retry unanswered CTA shows when eligible', (tester) async {
    var retried = false;
    const progress = CollectionsCallProgress(
      results: [
        CollectionsCallProgressRow(
          contactId: 'us',
          status: CollectionsCallRowStatus.completed,
          runId: 'run-us',
          outcome: CallRunOutcome.noAnswer,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 1,
            emailCount: 2,
            callLeadName: 'US Contact',
            pdfCount: 0,
            textCount: 2,
            callConsented: true,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            callProgress: progress,
            retryOfferCount: 1,
            onRetryUnanswered: () => retried = true,
            onCommit: ({required call, required send}) {},
          ),
        ),
      ),
    );

    expect(find.text('Retry unanswered — 1'), findsOneWidget);
    await tester.tap(find.text('Retry unanswered — 1'));
    await tester.pumpAndSettle();
    expect(retried, isTrue);
  });
}
