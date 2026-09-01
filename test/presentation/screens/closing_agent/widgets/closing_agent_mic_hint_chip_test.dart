import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_mic_hint_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hold hint chip shows mic icon and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ClosingAgentMicHintChip(message: 'Hold to speak'),
        ),
      ),
    );

    expect(find.text('Hold to speak'), findsOneWidget);
    expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
  });
}
