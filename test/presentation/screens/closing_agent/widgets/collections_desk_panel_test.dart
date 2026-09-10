import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_panel.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_row.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CollectionsDeskRow row(int index) {
    return CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: '$index',
        name: 'n$index',
        phone: '+9677000000$index',
        ledgerId: 'ledger',
        netBalance: -100,
        currencyCode: 'YER',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
      ),
      body: 'body $index',
      toneBand: ReminderToneBand.reminder,
      attachPdf: false,
    );
  }

  Widget panel({
    required List<CollectionsDeskRow> rows,
    required bool startSendingIsPrimary,
    String? busyContactId,
    bool isDispatching = false,
    bool isQueueInFlight = false,
    bool isQueuePaused = false,
    int queueIndex = 0,
    int queueTotal = 0,
    String queueContactName = '',
    VoidCallback? onQueuePause,
    VoidCallback? onQueueResume,
    VoidCallback? onQueueSkip,
    bool showHybridELeftover = false,
    bool showRetrySend = false,
    bool sendOutreachEnabled = true,
    double paddingBottom = 0,
    VoidCallback? onApproveAndSend,
  }) {
    return CollectionsDeskPanel(
      rows: rows,
      callCount: 1,
      emailCount: rows.length,
      callConsented: false,
      sendOutreachEnabled: sendOutreachEnabled,
      startSendingIsPrimary: startSendingIsPrimary,
      busyContactId: busyContactId,
      isDispatching: isDispatching,
      isQueueInFlight: isQueueInFlight,
      isQueuePaused: isQueuePaused,
      queueIndex: queueIndex,
      queueTotal: queueTotal,
      queueContactName: queueContactName,
      onCommitOutreach: ({required call, required send}) {},
      onSkip: (_) {},
      onCopy: (_) {},
      onOpen: (_) {},
      onTone: (_, _) {},
      onTogglePdf: (_) {},
      onStartSending: () {},
      onApproveAndSend: onApproveAndSend ?? () {},
      onDone: () {},
      onQueuePause: onQueuePause,
      onQueueResume: onQueueResume,
      onQueueSkip: onQueueSkip,
      showHybridELeftover: showHybridELeftover,
      showRetrySend: showRetrySend,
      paddingBottom: paddingBottom,
    );
  }

  testWidgets('SMTP desk shows consent card Confirm and Send, no WhatsApp', (
    tester,
  ) async {
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
          body: panel(
            rows: [for (var i = 0; i < 5; i++) row(i)],
            startSendingIsPrimary: true,
          ),
        ),
      ),
    );

    expect(find.byType(CollectionsDeskRowCard), findsNWidgets(5));
    expect(
      find.text('Confirm (1 call + 5 statements)'),
      findsOneWidget,
    );
    expect(find.text('Voice calls'), findsOneWidget);
    expect(find.text('Dispatch collection emails'), findsNothing);
    expect(find.text('Open collections desk'), findsNothing);
    expect(find.text('Open WhatsApp'), findsNothing);
    expect(find.text('Start sending'), findsNothing);
    expect(find.text('Pause'), findsNothing);
  });

  testWidgets('leftover Hybrid E still finds Open WhatsApp', (tester) async {
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
          body: panel(
            rows: [row(0)],
            startSendingIsPrimary: true,
            showHybridELeftover: true,
          ),
        ),
      ),
    );

    expect(find.text('Open WhatsApp'), findsWidgets);
    expect(find.text('Confirm & Send Statements'), findsOneWidget);
  });

  testWidgets('sticky bar shows Sending i of N, Open, Skip, Pause', (
    tester,
  ) async {
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
          body: panel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            showHybridELeftover: true,
            isQueueInFlight: true,
            queueIndex: 1,
            queueTotal: 2,
            queueContactName: 'n0',
            onQueuePause: () {},
            onQueueResume: () {},
            onQueueSkip: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sending 1 of 2'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsWidgets);
    expect(find.text('Skip'), findsWidgets);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Start sending'), findsNothing);
    expect(find.text('Skip outreach'), findsOneWidget);
    expect(find.text('Confirm & Send Statements'), findsNothing);
  });

  testWidgets('SMTP desk hides leftover sticky even if queue is in flight', (
    tester,
  ) async {
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
          body: panel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            isQueueInFlight: true,
            queueIndex: 1,
            queueTotal: 2,
            queueContactName: 'n0',
            onQueuePause: () {},
            onQueueResume: () {},
            onQueueSkip: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sending 1 of 2'), findsNothing);
    expect(find.text('Open WhatsApp'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    expect(
      find.text('Confirm (1 call + 2 statements)'),
      findsOneWidget,
    );
    expect(find.text('Skip outreach'), findsNothing);
  });

  testWidgets(
    'SMTP dispatching shows Sending, no sticky, no leftover Open',
    (tester) async {
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
            body: panel(
              rows: [row(0), row(1)],
              startSendingIsPrimary: true,
              isDispatching: true,
              queueIndex: 1,
              queueTotal: 2,
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Sending 1 of 2'),
        findsOneWidget,
      );
      expect(find.text('Start sending'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Confirm & Send Statements'), findsNothing);
      expect(find.text('Open WhatsApp'), findsNothing);
      expect(find.text('Skip outreach'), findsNothing);
    },
  );

  testWidgets(
    'leftover Open disabled while SMTP dispatching',
    (tester) async {
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
            body: panel(
              rows: [row(0), row(1)],
              startSendingIsPrimary: true,
              showHybridELeftover: true,
              isDispatching: true,
            ),
          ),
        ),
      );

      final openButtons = tester.widgetList<DaftarButton>(
        find.widgetWithText(DaftarButton, 'Open WhatsApp'),
      );
      expect(openButtons, isNotEmpty);
      for (final button in openButtons) {
        expect(button.onPressed, isNull);
      }
      final skipButtons = tester.widgetList<DaftarButton>(
        find.widgetWithText(DaftarButton, 'Skip'),
      );
      expect(skipButtons, isNotEmpty);
      for (final button in skipButtons) {
        expect(button.onPressed, isNull);
      }
    },
  );

  testWidgets('SMTP desk shows Retry sending after failed dispatch', (
    tester,
  ) async {
    var retryCount = 0;
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
          body: panel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            showRetrySend: true,
            onApproveAndSend: () => retryCount++,
          ),
        ),
      ),
    );

    expect(find.text('Retry sending'), findsOneWidget);
    expect(
      find.text('Confirm (1 call + 2 statements)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry sending'));
    await tester.pump();
    expect(retryCount, 1);
  });

  testWidgets('keyboard inset does not overflow the desk Column', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 386,
            child: panel(
              rows: [row(0), row(1)],
              startSendingIsPrimary: true,
              paddingBottom: 156,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Voice calls'), findsOneWidget);
  });
}
