import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLocale(WidgetTester tester, Locale locale) {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Column(
                children: [
                  Text(l10n.closingAgentEmptyTitle),
                  Text(l10n.closingAgentExampleChip1),
                  ClosingAgentComposer(
                    controller: controller,
                    isRunning: false,
                    sendIsPrimary: true,
                    onSubmit: (_) {},
                    onMicTap: () {},
                    onMicHoldStart: () {},
                    onMicHoldEnd: () {},
                    onMicHoldCancel: () {},
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('English agent chrome is LTR and not Arabic copy', (
    tester,
  ) async {
    await pumpLocale(tester, const Locale('en'));
    await tester.pump();

    expect(find.text('What should we record?'), findsOneWidget);
    expect(find.text('Mohamed paid 500'), findsOneWidget);
    expect(find.text('ما الذي نسجّل؟'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('What should we record?'))),
      TextDirection.ltr,
    );
  });

  testWidgets('Arabic agent chrome is RTL', (tester) async {
    await pumpLocale(tester, const Locale('ar'));
    await tester.pump();

    expect(find.text('ما الذي نسجّل؟'), findsOneWidget);
    expect(find.text('What should we record?'), findsNothing);
    expect(
      Directionality.of(tester.element(find.text('ما الذي نسجّل؟'))),
      TextDirection.rtl,
    );
  });
}
