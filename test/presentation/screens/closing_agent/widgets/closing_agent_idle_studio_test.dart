import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_idle_studio.dart';
import 'package:daftar/presentation/shared/widgets/khazna_specular_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({
    required Locale locale,
    required ValueChanged<String> onExampleSelected,
    required VoidCallback onCloseToday,
    bool keyboardOpen = false,
    bool disableAnimations = false,
    Size size = const Size(400, 800),
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: ClosingAgentIdleStudio(
            isDark: true,
            keyboardOpen: keyboardOpen,
            onExampleSelected: onExampleSelected,
            onCloseToday: onCloseToday,
          ),
        ),
      ),
    );
  }

  testWidgets('shows title, subtitle, examples, and Close Today seal', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (_) {},
        onCloseToday: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('What should we record?'), findsOneWidget);
    expect(find.text('Tap an example, or type the name and amount'), findsOneWidget);
    expect(find.text('Mohamed paid 500'), findsOneWidget);
    expect(find.text('Ahmed owes 200'), findsOneWidget);
    expect(find.text('Close today'), findsOneWidget);
    expect(find.byType(KhaznaSpecularPanel), findsNWidgets(3));
    expect(find.byKey(const ValueKey<String>('close-today-crescent')), findsOneWidget);
  });

  testWidgets('tapping a satellite invokes onExampleSelected', (
    tester,
  ) async {
    String? selected;
    var closeTodayTaps = 0;
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (value) => selected = value,
        onCloseToday: () => closeTodayTaps++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.text('Mohamed paid 500'));
    await tester.pump();

    expect(selected, 'Mohamed paid 500');
    expect(closeTodayTaps, 0);
  });

  testWidgets('tapping Close Today seal invokes onCloseToday', (
    tester,
  ) async {
    var closeTodayTaps = 0;
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (_) {},
        onCloseToday: () => closeTodayTaps++,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.text('Close today'));
    await tester.pump();

    expect(closeTodayTaps, 1);
  });

  testWidgets('Arabic idle studio is RTL and shows seal copy', (tester) async {
    await tester.pumpWidget(
      harness(
        locale: const Locale('ar'),
        onExampleSelected: (_) {},
        onCloseToday: () {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('ما الذي نسجّل؟'), findsOneWidget);
    expect(find.text('What should we record?'), findsNothing);
    expect(find.text('أقفل اليوم'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('ما الذي نسجّل؟'))),
      TextDirection.rtl,
    );
  });

  testWidgets('hides satellites and seal when keyboard is open', (tester) async {
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (_) {},
        onCloseToday: () {},
        keyboardOpen: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Mohamed paid 500'), findsNothing);
    expect(find.text('Close today'), findsNothing);
    expect(find.byType(KhaznaSpecularPanel), findsNothing);
  });

  testWidgets('compact layout uses wrap for satellites and seal below', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (_) {},
        onCloseToday: () {},
        size: const Size(340, 500),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byType(KhaznaSpecularPanel), findsNWidgets(3));
    expect(find.text('Mohamed paid 500'), findsOneWidget);
    expect(find.text('Close today'), findsOneWidget);
  });

  testWidgets('renders with reduce motion enabled', (tester) async {
    await tester.pumpWidget(
      harness(
        locale: const Locale('en'),
        onExampleSelected: (_) {},
        onCloseToday: () {},
        disableAnimations: true,
      ),
    );
    await tester.pump();

    expect(find.text('What should we record?'), findsOneWidget);
    expect(find.text('Close today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
