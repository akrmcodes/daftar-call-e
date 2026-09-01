import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_working_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness({
    required bool active,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Stack(
            children: [
              ClosingAgentWorkingGlow(active: active),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('active glow paints crest', (tester) async {
    await tester.pumpWidget(harness(active: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ClosingAgentWorkingGlow), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('deactivating glow still builds and fades', (tester) async {
    await tester.pumpWidget(harness(active: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(harness(active: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion active glow has no repeating breath leak', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(active: true, disableAnimations: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ClosingAgentWorkingGlow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
