import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fade dot matrix paints without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 300,
            child: ClosingAgentFadeDotMatrix(isDark: true),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
