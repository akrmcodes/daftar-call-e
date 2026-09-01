import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vault chrome renders child inside ceremony shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ClosingAgentVaultChrome(
              child: Text('Ceremony'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ceremony'), findsOneWidget);
  });
}
