import 'package:daftar/app/router/app_routes.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_coach_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  required Locale locale,
  required Widget home,
}) {
  return MaterialApp(
    navigatorKey: rootNavigatorKey,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      );
    },
    home: home,
  );
}

Widget _targetHome(GlobalKey targetKey, {Widget? child}) {
  return Scaffold(
    body: Center(
      child:
          child ??
          SizedBox(
            key: targetKey,
            width: 44,
            height: 44,
          ),
    ),
  );
}

Widget _realDockFabHome(GlobalKey targetKey) {
  return Scaffold(
    extendBody: true,
    body: const SizedBox.expand(),
    bottomNavigationBar: Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.spacingLg,
        end: AppDimensions.spacingLg,
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            SizedBox(
              key: targetKey,
              width: 44,
              height: 44,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pumpCoach(
  WidgetTester tester, {
  required GlobalKey targetKey,
  required VoidCallback onDismissed,
}) async {
  final future = DaftarCoachMark.showFab(
    context: tester.element(find.byType(Scaffold)),
    targetKey: targetKey,
    onDismissed: onDismissed,
  );
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final shown = await future;
  expect(shown, isTrue);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(DaftarCoachMark.removeOverlayForTest);

  testWidgets(
    'FAB coach tooltip is title plus tap and hold rows, not a paragraph',
    (tester) async {
      await tester.pumpWidget(
        _app(
          locale: const Locale('en'),
          home: Scaffold(
            body: DaftarCoachMarkTooltip(onGotIt: () {}),
          ),
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
    },
  );

  testWidgets('FAB coach tooltip localizes in Arabic RTL', (tester) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        home: Scaffold(
          body: DaftarCoachMarkTooltip(onGotIt: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(
      Directionality.of(tester.element(find.byType(DaftarCoachMarkTooltip))),
      TextDirection.rtl,
    );
    expect(find.text('Tap → agent'), findsNothing);
    expect(find.textContaining('اضغط → الوكيل'), findsOneWidget);
    expect(find.textContaining('اضغط مطولاً'), findsOneWidget);
  });

  testWidgets('overlay does not invoke FAB onTap or onLongPress', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    var taps = 0;
    var holds = 0;
    var dismissed = 0;

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _targetHome(
          targetKey,
          child: GestureDetector(
            key: targetKey,
            onTap: () => taps += 1,
            onLongPress: () => holds += 1,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: ColoredBox(color: Color(0xFF0356C5)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpCoach(
      tester,
      targetKey: targetKey,
      onDismissed: () => dismissed += 1,
    );

    expect(find.byKey(daftarCoachFabGotItKey), findsOneWidget);

    final center = tester.getCenter(find.byKey(targetKey));
    await tester.tapAt(center);
    await tester.pump();
    await tester.longPressAt(center);
    await tester.pump();

    expect(taps, 0);
    expect(holds, 0);
    expect(dismissed, 0);
  });

  testWidgets('Got it dismisses and persists via onDismissed', (tester) async {
    final targetKey = GlobalKey();
    var dismissed = 0;

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _targetHome(targetKey),
      ),
    );
    await tester.pump();
    await _pumpCoach(
      tester,
      targetKey: targetKey,
      onDismissed: () => dismissed += 1,
    );

    await tester.tap(find.byKey(daftarCoachFabGotItKey));
    await tester.pump();

    expect(dismissed, 1);
  });

  testWidgets('Skip dismisses and persists via onDismissed', (tester) async {
    final targetKey = GlobalKey();
    var dismissed = 0;

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _targetHome(targetKey),
      ),
    );
    await tester.pump();
    await _pumpCoach(
      tester,
      targetKey: targetKey,
      onDismissed: () => dismissed += 1,
    );

    await tester.tap(find.byKey(daftarCoachFabSkipKey));
    await tester.pump();

    expect(dismissed, 1);
  });

  testWidgets(
    'overlayTargetOf matches FAB center on real dock in LTR and RTL',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final targetKey = GlobalKey();
        await tester.pumpWidget(
          _app(
            locale: locale,
            home: _realDockFabHome(targetKey),
          ),
        );
        await tester.pump();

        final overlay = rootNavigatorKey.currentState!.overlay!;
        final rect = DaftarCoachMark.overlayTargetOf(targetKey, overlay);
        expect(rect, isNotNull, reason: 'locale $locale');

        final fabCenter = tester.getCenter(find.byKey(targetKey));
        final holeCenter = rect!.center;
        expect(
          holeCenter.dx,
          moreOrLessEquals(fabCenter.dx, epsilon: 1),
          reason: 'locale $locale dx',
        );
        expect(
          holeCenter.dy,
          moreOrLessEquals(fabCenter.dy, epsilon: 1),
          reason: 'locale $locale dy',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        DaftarCoachMark.removeOverlayForTest();
      }
    },
  );

  testWidgets(
    'painted spotlight hole centers on FAB on real dock in LTR and RTL',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final targetKey = GlobalKey();
        await tester.pumpWidget(
          _app(
            locale: locale,
            home: _realDockFabHome(targetKey),
          ),
        );
        await tester.pump();
        await _pumpCoach(
          tester,
          targetKey: targetKey,
          onDismissed: () {},
        );

        final fabCenter = tester.getCenter(find.byKey(targetKey));
        final hole = DaftarCoachMark.debugHoleRect;
        expect(hole, isNotNull, reason: 'locale $locale');
        final holeCenter = hole!.center;

        expect(
          holeCenter.dx,
          moreOrLessEquals(fabCenter.dx, epsilon: 1),
          reason: 'locale $locale hole dx',
        );
        expect(
          holeCenter.dy,
          moreOrLessEquals(fabCenter.dy, epsilon: 1),
          reason: 'locale $locale hole dy',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        DaftarCoachMark.removeOverlayForTest();
      }
    },
  );

  testWidgets(
    'tooltip card is centered on FAB and compact on real dock',
    (tester) async {
      const surfaces = [
        Size(360, 640),
        Size(320, 568),
        Size(412, 915),
      ];
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final surface in surfaces) {
          await tester.binding.setSurfaceSize(surface);
          final targetKey = GlobalKey();
          await tester.pumpWidget(
            _app(
              locale: locale,
              home: _realDockFabHome(targetKey),
            ),
          );
          await tester.pump();
          await _pumpCoach(
            tester,
            targetKey: targetKey,
            onDismissed: () {},
          );

          final fabRect = tester.getRect(find.byKey(targetKey));
          final cardRect =
              tester.getRect(find.byKey(daftarCoachFabTooltipCardKey));
          final fabCenterX = fabRect.center.dx;
          final cardCenterX = cardRect.center.dx;

          expect(
            cardCenterX,
            moreOrLessEquals(fabCenterX, epsilon: 1),
            reason: 'locale $locale surface $surface',
          );
          expect(
            cardRect.left,
            greaterThanOrEqualTo(AppDimensions.pagePaddingH - 1),
            reason: 'locale $locale surface $surface left',
          );
          expect(
            cardRect.right,
            lessThanOrEqualTo(surface.width - AppDimensions.pagePaddingH + 1),
            reason: 'locale $locale surface $surface right',
          );
          expect(
            cardRect.width,
            lessThan(surface.width * 0.85),
            reason: 'locale $locale surface $surface width',
          );
          expect(
            cardRect.width,
            lessThanOrEqualTo(240),
            reason: 'locale $locale surface $surface max card',
          );

          DaftarCoachMark.removeOverlayForTest();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    },
  );

  testWidgets('isTargetLaidOut is false until the FAB has a real size', (
    tester,
  ) async {
    expect(DaftarCoachMark.isTargetLaidOut(GlobalKey()), isFalse);

    final zeroKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _targetHome(
          zeroKey,
          child: SizedBox.shrink(key: zeroKey),
        ),
      ),
    );
    await tester.pump();
    expect(DaftarCoachMark.isTargetLaidOut(zeroKey), isFalse);

    final laidOutKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _targetHome(laidOutKey),
      ),
    );
    await tester.pump();
    expect(DaftarCoachMark.isTargetLaidOut(laidOutKey), isTrue);
  });

  testWidgets('isTargetLaidOut passes for real dock FAB', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: _realDockFabHome(targetKey),
      ),
    );
    await tester.pump();

    expect(DaftarCoachMark.isTargetLaidOut(targetKey), isTrue);
  });

  testWidgets('showFab is a no-op when the target is not laid out', (
    tester,
  ) async {
    final targetKey = GlobalKey();
    var dismissed = 0;

    await tester.pumpWidget(
      _app(
        locale: const Locale('en'),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();

    final showFuture = DaftarCoachMark.showFab(
      context: tester.element(find.byType(Scaffold)),
      targetKey: targetKey,
      onDismissed: () => dismissed += 1,
    );
    expect(await showFuture, isFalse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byKey(daftarCoachFabGotItKey), findsNothing);
    expect(dismissed, 0);
  });
}
