import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_theme.dart';
import 'package:daftar/application/settings/complete_onboarding_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:daftar/presentation/providers/locale_provider.dart' as locale_prov;
import 'package:daftar/presentation/providers/merchant_profile_providers.dart';
import 'package:daftar/presentation/providers/premium_providers.dart';
import 'package:daftar/presentation/providers/settings_preferences_provider.dart';
import 'package:daftar/presentation/providers/theme_provider.dart' as theme_prov;
import 'package:daftar/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_store_beat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

class _Harness {
  bool googleFails = false;
  bool activateFails = true;
  bool driveGrantReady = true;
  bool driveGrantFails = false;
  int googleCalls = 0;
  int activateCalls = 0;
  int driveGrantCalls = 0;
  int completeCalls = 0;
  String? storedName;
  final createdLedgers = <LedgerType>[];
  final createdLedgerNames = <String>[];
}

class _TestLocale extends locale_prov.Locale {
  _TestLocale(this.initial);

  final ui.Locale initial;

  @override
  ui.Locale build() => initial;

  @override
  void setLocale(ui.Locale locale) {
    state = locale;
  }
}

class _TestTheme extends theme_prov.Theme {
  @override
  ThemeMode build() => ThemeMode.system;

  @override
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

class _TestSettingsPreferences extends SettingsPreferences {
  @override
  void build() {}

  @override
  Future<bool> setDefaultCurrency(String code) async => true;
}

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.harness);

  final _Harness harness;

  @override
  Future<Either<Failure, AppSettings>> get() async =>
      const Right(AppSettings());

  @override
  Future<Either<Failure, AppSettings>> update(
    UpdateSettingsParams params,
  ) async {
    if (params.hasSeenOnboarding == true) {
      harness.completeCalls++;
    }
    return Right(
      AppSettings(hasSeenOnboarding: params.hasSeenOnboarding ?? false),
    );
  }

  @override
  Stream<AppSettings> watchSettings() =>
      Stream.value(const AppSettings(analyticsEnabled: false));
}

class _TestSignInController extends SignInController {
  _TestSignInController(this.harness);

  final _Harness harness;

  @override
  FutureOr<void> build() {}

  @override
  Future<Either<Failure, Unit>> signInWithGoogle() async {
    harness.googleCalls++;
    if (harness.googleFails) {
      return const Left(AuthFailure('google failed'));
    }
    return const Right(unit);
  }
}

class _TestDriveOfflineGrantController extends DriveOfflineGrantController {
  _TestDriveOfflineGrantController(this.harness);

  final _Harness harness;

  @override
  FutureOr<void> build() {}

  @override
  Future<Either<Failure, Unit>> completeDriveAuthorization() async {
    harness.driveGrantCalls++;
    if (harness.driveGrantFails) {
      return const Left(AuthFailure('grant failed'));
    }
    harness.driveGrantReady = true;
    return const Right(unit);
  }
}

class _TestActivateCodeController extends ActivateCodeController {
  _TestActivateCodeController(this.harness);

  final _Harness harness;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> activate(String formattedCode) async {
    harness.activateCalls++;
    return !harness.activateFails;
  }
}

class _TestMerchantProfileController extends MerchantProfileController {
  _TestMerchantProfileController(this.harness);

  final _Harness harness;
  static final _now = DateTime.utc(2026, 8, 22);

  @override
  FutureOr<void> build() {}

  @override
  Future<MerchantProfile?> updateProfile({
    required String storeName,
    String? storePhone,
  }) async {
    harness.storedName = storeName;
    return MerchantProfile(
      id: 'merchant-1',
      storeName: storeName,
      createdAt: _now,
      updatedAt: _now,
    );
  }
}

class _TestLedgerController extends LedgerController {
  _TestLedgerController(this.harness);

  final _Harness harness;
  static final _now = DateTime.utc(2026, 8, 22);

  @override
  void build() {}

  @override
  Future<Either<Failure, Ledger>> createLedger({
    required String name,
    required LedgerType type,
    required String icon,
    required int color,
  }) async {
    harness.createdLedgers.add(type);
    harness.createdLedgerNames.add(name);
    return Right(
      Ledger(
        id: 'ledger-${harness.createdLedgers.length}',
        name: name,
        type: type,
        icon: icon,
        color: '#64748B',
        sortOrder: 0,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
  }
}

class _Host extends ConsumerWidget {
  const _Host({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      locale: ref.watch(locale_prov.localeProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(theme_prov.themeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

Ledger _existingLedger() {
  final now = DateTime.utc(2026);
  return Ledger(
    id: 'existing',
    name: 'Existing',
    type: LedgerType.customers,
    icon: 'people_alt_rounded',
    color: '#64748B',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpOnboarding(
  WidgetTester tester, {
  required _Harness harness,
  List<Ledger> ledgers = const [],
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  tester.binding.platformDispatcher.localeTestValue = locale;
  tester.binding.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

  final router = _router();
  addTearDown(router.dispose);
  final settings = _FakeSettingsRepository(harness);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          (ref) => Stream<AppSettings>.value(
            AppSettings(
              analyticsEnabled: false,
              locale: locale.languageCode,
            ),
          ),
        ),
        locale_prov.localeProvider.overrideWith(() => _TestLocale(locale)),
        theme_prov.themeProvider.overrideWith(_TestTheme.new),
        settingsPreferencesProvider.overrideWith(_TestSettingsPreferences.new),
        entitlementProvider.overrideWith((ref) => Entitlement.defaultFree()),
        ledgersProvider.overrideWith(
          (ref) => Stream<List<Ledger>>.value(ledgers),
        ),
        completeOnboardingUseCaseProvider.overrideWithValue(
          CompleteOnboardingUseCase(settings),
        ),
        signInControllerProvider.overrideWith(
          () => _TestSignInController(harness),
        ),
        driveOfflineGrantReadyProvider.overrideWith(
          (ref) async => harness.driveGrantReady,
        ),
        driveOfflineGrantControllerProvider.overrideWith(
          () => _TestDriveOfflineGrantController(harness),
        ),
        merchantProfileProvider.overrideWith(
          (ref) => Stream<MerchantProfile?>.value(
            harness.storedName == null
                ? null
                : MerchantProfile(
                    id: 'merchant-1',
                    storeName: harness.storedName!,
                    createdAt: DateTime.utc(2026, 8, 22),
                    updatedAt: DateTime.utc(2026, 8, 22),
                  ),
          ),
        ),
        activateCodeControllerProvider.overrideWith(
          () => _TestActivateCodeController(harness),
        ),
        merchantProfileControllerProvider.overrideWith(
          () => _TestMerchantProfileController(harness),
        ),
        ledgerControllerProvider.overrideWith(
          () => _TestLedgerController(harness),
        ),
      ],
      child: _Host(router: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

GoRouter _router() {
  return GoRouter(
    initialLocation: RouteNames.onboardingPath,
    routes: [
      GoRoute(
        path: RouteNames.onboardingPath,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.homePath,
        builder: (context, state) => const Scaffold(
          body: Text('HOME', key: ValueKey<String>('onboarding-home')),
        ),
      ),
    ],
  );
}

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('onboarding-next')));
  await tester.pump();
  await tester.pump();
}

Future<void> _tapSkip(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('onboarding-skip')));
  await tester.pump();
  await tester.pump();
}

Future<void> _advanceToGoogle(WidgetTester tester) async {
  await _tapNext(tester); // language
  await _tapNext(tester); // look
  await _tapNext(tester); // store
  await _tapNext(tester); // google
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('language tap English flips Directionality to LTR before Look', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(
      tester,
      harness: harness,
      locale: const Locale('ar'),
    );

    await _tapNext(tester);
    expect(find.byKey(const ValueKey<String>('onboarding-language-en')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding-language-en')));
    await tester.pump();
    await tester.pump();

    final onLanguage = tester.element(find.byType(OnboardingScreen));
    expect(Directionality.of(onLanguage), TextDirection.ltr);

    await _tapNext(tester);
    expect(find.text('Look'), findsOneWidget);
    final onLook = tester.element(find.byType(OnboardingScreen));
    expect(Directionality.of(onLook), TextDirection.ltr);
  });

  testWidgets('Google later plus remaining skips complete to home', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness, ledgers: [_existingLedger()]);

    await _advanceToGoogle(tester);
    expect(find.text('Save a copy on Google'), findsOneWidget);

    await _tapSkip(tester);
    expect(find.text('Have a code?'), findsOneWidget);

    await _tapNext(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('onboarding-home')), findsOneWidget);
    expect(harness.completeCalls, 1);
    expect(harness.googleCalls, 0);
    expect(harness.createdLedgers, isEmpty);
  });

  testWidgets('failed Google sign-in stays on beat and does not complete', (
    tester,
  ) async {
    final harness = _Harness()..googleFails = true;
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapNext(tester);

    expect(find.byKey(const ValueKey<String>('onboarding-google-error')), findsOneWidget);
    expect(find.text('Save a copy on Google'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('onboarding-home')), findsNothing);
    expect(harness.completeCalls, 0);
    expect(harness.googleCalls, 1);
  });

  testWidgets('invalid Pro code shows error then Continue still advances', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapSkip(tester);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding-pro-expander')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('onboarding-pro-code')),
      'NOPE',
    );
    await tester.pump();

    await _tapNext(tester);
    expect(find.text('Invalid code. Check the code and try again.'), findsOneWidget);
    expect(harness.activateCalls, 1);
    expect(harness.completeCalls, 0);

    await _tapNext(tester);
    expect(find.text('First ledger'), findsOneWidget);
    expect(harness.completeCalls, 0);
  });

  testWidgets('empty ledgers: chip creates one ledger then completes', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapSkip(tester);
    await _tapNext(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('onboarding-ledger-customers')),
    );
    await tester.pump();
    await tester.pump();

    expect(harness.createdLedgers, [LedgerType.customers]);
    expect(harness.completeCalls, 1);
    expect(find.byKey(const ValueKey<String>('onboarding-home')), findsOneWidget);
  });

  testWidgets('non-empty ledgers skip create and still complete', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness, ledgers: [_existingLedger()]);

    await _advanceToGoogle(tester);
    await _tapSkip(tester);
    await _tapNext(tester);
    await tester.pump();

    expect(harness.createdLedgers, isEmpty);
    expect(harness.completeCalls, 1);
    expect(find.byKey(const ValueKey<String>('onboarding-home')), findsOneWidget);
  });

  testWidgets('store beat does not overflow when keyboard is open', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 320),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: Scaffold(
            body: OnboardingStoreBeat(
              nameController: controller,
              isPro: false,
              onPickLogo: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('Google sign-in without Drive grant stays on beat', (
    tester,
  ) async {
    final harness = _Harness()..driveGrantReady = false;
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapNext(tester);

    expect(harness.googleCalls, 1);
    expect(harness.completeCalls, 0);
    expect(find.text('Complete Drive access'), findsOneWidget);
    expect(find.text('Save a copy on Google'), findsOneWidget);
  });

  testWidgets('Complete Drive access advances after grant', (tester) async {
    final harness = _Harness()..driveGrantReady = false;
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapNext(tester);
    await _tapNext(tester);

    expect(harness.driveGrantCalls, 1);
    expect(find.text('Have a code?'), findsOneWidget);
    expect(harness.completeCalls, 0);
  });

  testWidgets('store name appears on Pro beat', (tester) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness);

    await _tapNext(tester);
    await _tapNext(tester);
    await _tapNext(tester);
    await tester.enterText(
      find.byType(TextField),
      'Al-Ghanem shop',
    );
    await tester.pump();
    await _tapNext(tester);
    await _tapSkip(tester);

    expect(find.text('Al-Ghanem shop'), findsOneWidget);
    expect(find.text('Pro branding'), findsOneWidget);
  });

  testWidgets('custom ledger name creates ledger on onboarding', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness);

    await _advanceToGoogle(tester);
    await _tapSkip(tester);
    await _tapNext(tester);

    await tester.tap(find.byKey(const ValueKey<String>('onboarding-ledger-custom')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('onboarding-ledger-custom-name')),
      'Workshop debts',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('onboarding-ledger-create')));
    await tester.pump();
    await tester.pump();

    expect(harness.createdLedgers, [LedgerType.custom]);
    expect(harness.createdLedgerNames, ['Workshop debts']);
    expect(harness.completeCalls, 1);
  });

  testWidgets('disableAnimations pump does not leave pending timers', (
    tester,
  ) async {
    final harness = _Harness();
    await _pumpOnboarding(tester, harness: harness);

    await _tapNext(tester);
    await _tapNext(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  test('debug seeder keeps hasSeenOnboarding true', () {
    final source = File('lib/core/utils/dev_database_seeder.dart').readAsStringSync();
    expect(source.contains('hasSeenOnboarding: Value(true)'), isTrue);
  });
}
