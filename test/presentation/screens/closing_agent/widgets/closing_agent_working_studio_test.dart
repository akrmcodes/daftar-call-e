import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_working_studio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({bool disableAnimations = false}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const Scaffold(
          body: ClosingAgentWorkingStudio(isDark: true),
        ),
      ),
    );
  }

  testWidgets('shows clerk copy and no body spinner', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Reconciling ledger entries...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Working ·'), findsNothing);
  });

  testWidgets('reduce motion still shows clerk copy', (tester) async {
    await tester.pumpWidget(harness(disableAnimations: true));
    await tester.pump();

    expect(find.text('Reconciling ledger entries...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
