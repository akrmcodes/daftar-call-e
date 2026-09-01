import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_launch_curtain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({bool disableAnimations = false}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      );
    },
    home: const Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DaftarLaunchCurtain(),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reduce-motion dismisses immediately without hanging', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(DaftarLaunchCurtain.overlayKey), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('animated curtain shows brand mark immediately then dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byKey(DaftarLaunchCurtain.overlayKey), findsOneWidget);
    expect(find.byType(DaftarBrandMark), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byKey(DaftarLaunchCurtain.overlayKey), findsNothing);
  });
}
