import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_ritual_reminder_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Yes / Top 5 / No are all tappable', (tester) async {
    final chosen = <ClosingReminderPolicy>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ClosingRitualReminderPrompt(
            primaryIsOwned: true,
            onChosen: chosen.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Yes'));
    await tester.tap(find.text('Top 5'));
    await tester.tap(find.text('No'));

    expect(
      chosen,
      [
        ClosingReminderPolicy.all,
        ClosingReminderPolicy.top5,
        ClosingReminderPolicy.none,
      ],
    );
  });
}
