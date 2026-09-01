import 'package:daftar/presentation/shared/widgets/khazna_radial_well.dart';
import 'package:daftar/presentation/shared/widgets/khazna_specular_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KhaznaSpecularPanel renders child and handles tap', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: KhaznaSpecularPanel(
              onTap: () => tapped = true,
              child: const Text('Intent'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Intent'), findsOneWidget);
    expect(find.byType(KhaznaSpecularPanel), findsOneWidget);

    await tester.tap(find.text('Intent'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('KhaznaRadialWell renders without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KhaznaRadialWell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KhaznaRadialWell), findsOneWidget);
  });

  testWidgets('KhaznaRadialWell respects dim opacity', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KhaznaRadialWell(opacity: 0.35),
        ),
      ),
    );
    await tester.pump();

    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(KhaznaRadialWell),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0.35);
  });
}
