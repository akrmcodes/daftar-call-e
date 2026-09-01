import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/agent_fab_tip_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FAB tip is title plus tap and hold rows, not a paragraph', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const Scaffold(body: AgentFabTipSheet()),
      ),
    );
    await tester.pump();

    expect(find.text('Agent and manual entry'), findsOneWidget);
    expect(find.text('Tap → agent'), findsOneWidget);
    expect(find.text('Hold → manual entry'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(
      find.text('Tap for the agent · press and hold for manual entry'),
      findsNothing,
    );
  });

  testWidgets('FAB tip rows localize in Arabic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const Scaffold(body: AgentFabTipSheet()),
      ),
    );
    await tester.pump();

    expect(find.text('Tap → agent'), findsNothing);
    expect(find.textContaining('اضغط → الوكيل'), findsOneWidget);
    expect(find.textContaining('اضغط مطولاً'), findsOneWidget);
  });
}
