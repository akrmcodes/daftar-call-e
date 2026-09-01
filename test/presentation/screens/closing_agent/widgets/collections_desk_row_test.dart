import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_row.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CollectionsDeskRow aminaRow() {
    return const CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: 'c1',
        name: 'Amina',
        phone: '+967700000001',
        ledgerId: 'ledger',
        netBalance: -1500,
        currencyCode: 'YER',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
      ),
      body: 'Peace be upon you Amina, this is Daftar.',
      toneBand: ReminderToneBand.reminder,
      attachPdf: false,
    );
  }

  testWidgets('SMTP default has Copy, no Open WhatsApp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: aminaRow(),
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

    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Reminder only'), findsOneWidget);
    expect(find.text('PDF attached'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.byType(CupertinoSwitch), findsNothing);
    expect(find.text('Friendly'), findsNothing);
    expect(find.text('Reminder'), findsNothing);
    expect(find.text('Firm'), findsNothing);
  });

  testWidgets('leftover Hybrid E still shows Open / Copy / Skip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: aminaRow(),
            isOpening: false,
            showHybridELeftover: true,
            onSkip: () {},
            onCopy: () {},
            onOpen: () {},
            onTone: (_) {},
            onTogglePdf: () {},
          ),
        ),
      ),
    );

    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);
  });

  testWidgets('row shows last-payment recency when present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: const CollectionsDeskRow(
              candidate: CollectionsCandidate(
                contactId: 'c1',
                name: 'Amina',
                phone: '+967700000001',
                ledgerId: 'ledger',
                netBalance: -1500,
                currencyCode: 'YER',
                ageDays: 40,
                toneBand: ReminderToneBand.reminder,
                daysSinceLastPayment: 3,
              ),
              body: 'Peace be upon you Amina, this is Daftar.',
              toneBand: ReminderToneBand.reminder,
              attachPdf: false,
            ),
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

    expect(find.text('Last payment 3 days ago'), findsOneWidget);
    expect(find.text('never paid'), findsNothing);
  });

  testWidgets('leftover Open Skip tone attach disabled while SMTP dispatching', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRowCard(
            row: aminaRow(),
            isOpening: false,
            leftoverActionsEnabled: false,
            showHybridELeftover: true,
            onSkip: () {},
            onCopy: () {},
            onOpen: () {},
            onTone: (_) {},
            onTogglePdf: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<DaftarButton>(
            find.widgetWithText(DaftarButton, 'Open WhatsApp'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DaftarButton>(find.widgetWithText(DaftarButton, 'Skip'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DaftarButton>(find.widgetWithText(DaftarButton, 'Copy'))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
      isNull,
    );
  });
}
