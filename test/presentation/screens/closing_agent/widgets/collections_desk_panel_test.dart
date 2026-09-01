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

  testWidgets('SMTP desk has live dispatch, no Approve, no Open WhatsApp', (
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
          body: CollectionsDeskPanel(
            rows: [for (var i = 0; i < 5; i++) row(i)],
            startSendingIsPrimary: true,
            busyContactId: null,
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

    expect(find.byType(CollectionsDeskRowCard), findsNWidgets(5));
    expect(find.text('Confirm & Send Statements'), findsNothing);
    expect(find.text('Skip outreach'), findsNothing);
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
          body: CollectionsDeskPanel(
            rows: [row(0)],
            startSendingIsPrimary: true,
            busyContactId: null,
            showHybridELeftover: true,
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
          body: CollectionsDeskPanel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            busyContactId: null,
            showHybridELeftover: true,
            isQueueInFlight: true,
            queueIndex: 1,
            queueTotal: 2,
            queueContactName: 'n0',
            onSkip: (_) {},
            onCopy: (_) {},
            onOpen: (_) {},
            onTone: (_, _) {},
            onTogglePdf: (_) {},
            onStartSending: () {},
            onApproveAndSend: () {},
            onDone: () {},
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
          body: CollectionsDeskPanel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            busyContactId: null,
            isQueueInFlight: true,
            queueIndex: 1,
            queueTotal: 2,
            queueContactName: 'n0',
            onSkip: (_) {},
            onCopy: (_) {},
            onOpen: (_) {},
            onTone: (_, _) {},
            onTogglePdf: (_) {},
            onStartSending: () {},
            onApproveAndSend: () {},
            onDone: () {},
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
    expect(find.text('Confirm & Send Statements'), findsNothing);
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
            body: CollectionsDeskPanel(
              rows: [row(0), row(1)],
              startSendingIsPrimary: true,
              busyContactId: null,
              isDispatching: true,
              queueIndex: 1,
              queueTotal: 2,
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
            body: CollectionsDeskPanel(
              rows: [row(0), row(1)],
              startSendingIsPrimary: true,
              busyContactId: null,
              showHybridELeftover: true,
              isDispatching: true,
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
          body: CollectionsDeskPanel(
            rows: [row(0), row(1)],
            startSendingIsPrimary: true,
            busyContactId: null,
            showRetrySend: true,
            onSkip: (_) {},
            onCopy: (_) {},
            onOpen: (_) {},
            onTone: (_, _) {},
            onTogglePdf: (_) {},
            onStartSending: () {},
            onApproveAndSend: () => retryCount++,
            onDone: () {},
          ),
        ),
      ),
    );

    expect(find.text('Retry sending'), findsOneWidget);
    expect(find.text('Confirm & Send Statements'), findsNothing);
    await tester.tap(find.text('Retry sending'));
    await tester.pump();
    expect(retryCount, 1);
  });
}
