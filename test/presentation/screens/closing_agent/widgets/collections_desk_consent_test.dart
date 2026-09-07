import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/collections_call_task_composer.dart';
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

  CollectionsDeskRow usRow() {
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
      attachPdf: false,
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

  testWidgets('consent card shows dual CTAs without promise banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 1,
            emailCount: 2,
            callConsented: false,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            onConfirmAndCall: () {},
            onConfirmAndSend: () {},
            onConfirmWithoutCalling: () {},
            onConfirmWithoutSending: () {},
          ),
        ),
      ),
    );

    expect(find.text('Confirm & Call'), findsOneWidget);
    expect(find.text('Confirm & Send Statements'), findsOneWidget);
    expect(find.text('Without calling'), findsOneWidget);
    expect(find.text('Without sending'), findsOneWidget);
    expect(find.text('A promise is not a payment'), findsNothing);
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
        CollectionsCallProgressRow(contactId: 'a', status: CollectionsCallRowStatus.planned),
        CollectionsCallProgressRow(contactId: 'b', status: CollectionsCallRowStatus.planned),
        CollectionsCallProgressRow(contactId: 'c', status: CollectionsCallRowStatus.completed),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 3,
            emailCount: 0,
            callConsented: true,
            sendOutreachEnabled: false,
            busy: false,
            isDispatching: false,
            callProgress: progress,
            onConfirmAndCall: () {},
            onConfirmAndSend: () {},
            onConfirmWithoutCalling: () {},
            onConfirmWithoutSending: () {},
          ),
        ),
      ),
    );

    expect(find.text('Calling 1 of 3'), findsOneWidget);
  });

  testWidgets('SMTP desk shows Confirm and Send on consent card', (tester) async {
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
            onConfirmAndCall: () {},
            onConfirmWithoutCalling: () {},
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

    expect(find.text('Confirm & Send Statements'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
  });

  testWidgets('RTL smoke shows Arabic consent labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 1,
            emailCount: 1,
            callConsented: false,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            onConfirmAndCall: () {},
            onConfirmAndSend: () {},
            onConfirmWithoutCalling: () {},
            onConfirmWithoutSending: () {},
          ),
        ),
      ),
    );

    expect(find.text('تأكيد والاتصال'), findsOneWidget);
    expect(find.text('دون اتصال'), findsOneWidget);
  });

  testWidgets('YE-only desk hides Confirm and Call', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 0,
            emailCount: 2,
            callConsented: false,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            onConfirmAndCall: () {},
            onConfirmAndSend: () {},
            onConfirmWithoutCalling: () {},
            onConfirmWithoutSending: () {},
          ),
        ),
      ),
    );

    expect(find.text('Confirm & Call'), findsNothing);
    expect(find.text('Without calling'), findsNothing);
    expect(find.text('Confirm & Send Statements'), findsOneWidget);
  });

  testWidgets('Confirm and Send remains visible after call consented', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskConsentCard(
            callCount: 1,
            emailCount: 2,
            callConsented: true,
            sendOutreachEnabled: true,
            busy: false,
            isDispatching: false,
            onConfirmAndCall: () {},
            onConfirmAndSend: () {},
            onConfirmWithoutCalling: () {},
            onConfirmWithoutSending: () {},
          ),
        ),
      ),
    );

    expect(find.text('Confirm & Call'), findsNothing);
    expect(find.text('Confirm & Send Statements'), findsOneWidget);
  });
}
