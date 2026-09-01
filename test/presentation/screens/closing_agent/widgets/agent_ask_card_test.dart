import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/device_tts.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_ask_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  Future<void> pumpCard(
    WidgetTester tester,
    AskBooksAnswer answer, {
    String ttsLocale = 'en',
    bool ttsMuted = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentAskCard(
            answer: answer,
            isDark: true,
            ttsMuted: ttsMuted,
            ttsLocale: ttsLocale,
          ),
        ),
      ),
    );
  }

  testWidgets('largest outstanding uses largest title', (tester) async {
    await pumpCard(
      tester,
      const AskBooksLargestOutstanding([
        AskBooksBalanceRow(
          contactId: 'contact-1',
          contactName: 'Ali',
          netBalance: -900,
          currencyCode: 'YER',
        ),
      ]),
    );

    expect(find.text('Largest outstanding'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('last payment uses last-payment title', (tester) async {
    await pumpCard(
      tester,
      AskBooksLastTransaction(
        contactId: 'contact-1',
        contactName: 'Mohamed',
        amountMinor: 150,
        currencyCode: 'YER',
        transactionDate: DateTime.utc(2026, 8, 14),
        type: TransactionType.payment,
      ),
    );

    expect(find.text('Last payment'), findsOneWidget);
    expect(find.text('Mohamed'), findsOneWidget);
  });

  testWidgets('smallest outstanding uses smallest title', (tester) async {
    await pumpCard(
      tester,
      const AskBooksSmallestOutstanding([
        AskBooksBalanceRow(
          contactId: 'contact-1',
          contactName: 'Ali',
          netBalance: -200,
          currencyCode: 'YER',
        ),
      ]),
    );

    expect(find.text('Smallest outstanding'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('named balance card speaks the Drift facts', (tester) async {
    AgentSpeech.debugReset();
    DeviceTts.debugReset();
    final spoken = <String>[];
    DeviceTts.debugSpeakOverride = (text, {required locale}) async {
      spoken.add(text);
    };

    await pumpCard(
      tester,
      const AskBooksNamedBalance(
        AskBooksBalanceRow(
          contactId: 'contact-1',
          contactName: 'Mohamed',
          netBalance: -500,
          currencyCode: 'YER',
        ),
      ),
      ttsMuted: false,
    );
    await tester.pump();
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(spoken, ['Mohamed owes 500 riyals']);
  });
}
