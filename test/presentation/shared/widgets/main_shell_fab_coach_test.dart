import 'package:daftar/app/router/app_routes.dart';
import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/application/settings/mark_agent_fab_tip_seen_use_case.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/shared/widgets/daftar_coach_mark.dart';
import 'package:daftar/presentation/shared/widgets/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class _MockMarkAgentFabTipSeenUseCase extends Mock
    implements MarkAgentFabTipSeenUseCase {}

const _inlineFabKey = ValueKey<String>('main-shell-inline-fab');

Finder _fabSpotlightTarget(WidgetTester tester) {
  return find.descendant(
    of: find.byKey(_inlineFabKey),
    matching: find.byIcon(Icons.add_rounded),
  );
}

Widget _mainShellApp({
  required Locale locale,
  required AppSettings settings,
  required MarkAgentFabTipSeenUseCase markSeen,
}) {
  final ledger = Ledger(
    id: 'ledger-1',
    name: 'Test',
    type: LedgerType.custom,
    icon: 'store',
    color: '#000000',
    sortOrder: 0,
    createdAt: DateTime.utc(2026, 8, 22),
    updatedAt: DateTime.utc(2026, 8, 22),
  );

  return ProviderScope(
    overrides: [
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(settings),
      ),
      ledgersProvider.overrideWith(
        (ref) => Stream<List<Ledger>>.value([ledger]),
      ),
      markAgentFabTipSeenUseCaseProvider.overrideWithValue(markSeen),
    ],
    child: MaterialApp(
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
      home: const MainShell(
        currentLocation: RouteNames.homePath,
        child: SizedBox.expand(),
      ),
    ),
  );
}

Future<void> _waitForCoach(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    if (find.byKey(daftarCoachFabGotItKey).evaluate().isNotEmpty &&
        DaftarCoachMark.debugHoleRect != null) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMarkAgentFabTipSeenUseCase markSeen;

  setUp(() {
    markSeen = _MockMarkAgentFabTipSeenUseCase();
    when(() => markSeen.execute()).thenAnswer(
      (_) async => const Right(AppSettings(hasSeenAgentFabTip: true)),
    );
  });

  tearDown(DaftarCoachMark.removeOverlayForTest);

  testWidgets('shows FAB coach on home when tip not seen', (tester) async {
    await tester.pumpWidget(
      _mainShellApp(
        locale: const Locale('en'),
        settings: const AppSettings(hasSeenOnboarding: true),
        markSeen: markSeen,
      ),
    );

    await tester.pump();
    await tester.pump();
    await _waitForCoach(tester);

    expect(find.byKey(daftarCoachFabGotItKey), findsOneWidget);

    await tester.tap(find.byKey(daftarCoachFabGotItKey));
    await tester.pump();
    await tester.pump();

    verify(() => markSeen.execute()).called(1);
  });

  testWidgets(
    'spotlight hole centers on glass dock FAB in LTR and RTL',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        await tester.pumpWidget(
          _mainShellApp(
            locale: locale,
            settings: const AppSettings(hasSeenOnboarding: true),
            markSeen: markSeen,
          ),
        );
        await tester.pump();
        await tester.pump();
        await _waitForCoach(tester);

        final fabCenter = tester.getCenter(_fabSpotlightTarget(tester));
        final hole = DaftarCoachMark.debugHoleRect;
        expect(hole, isNotNull, reason: 'locale $locale');
        expect(
          hole!.center.dx,
          moreOrLessEquals(fabCenter.dx, epsilon: 2),
          reason: 'locale $locale dx',
        );
        expect(
          hole.center.dy,
          moreOrLessEquals(fabCenter.dy, epsilon: 2),
          reason: 'locale $locale dy',
        );

        DaftarCoachMark.removeOverlayForTest();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('does not show FAB coach before onboarding completes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _mainShellApp(
        locale: const Locale('en'),
        settings: const AppSettings(),
        markSeen: markSeen,
      ),
    );

    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(find.byKey(daftarCoachFabGotItKey), findsNothing);
    verifyNever(() => markSeen.execute());
  });
}
