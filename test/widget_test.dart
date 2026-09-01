import 'package:daftar/app/app.dart';
import 'package:daftar/app/router/app_router_provider.dart';
import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact_balance.dart' as domain;
import 'package:daftar/domain/entities/ledger.dart' as domain;
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/ledger_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the localized shell home screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 2560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDaftarApp(tester);

    expect(find.text('مرحباً'), findsOneWidget);
    expect(find.text('دفاتري'), findsOneWidget);
    expect(find.byKey(const ValueKey('main-shell-tab-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('main-shell-tab-1')), findsOneWidget);
  });

  testWidgets(
    'moves the shell indicator to settings and keeps it active for nested settings routes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpDaftarApp(tester);

      expect(find.text('مرحباً'), findsOneWidget);

      final element = tester.element(find.byType(DaftarApp));
      final container = ProviderScope.containerOf(element);
      container.read(goRouterProvider).go(RouteNames.settingsPath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('مرحباً'), findsNothing);

      container.read(goRouterProvider).go(RouteNames.backupPath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('النسخ الاحتياطي والاستعادة'), findsOneWidget);
      expect(find.text('مرحباً'), findsNothing);
    },
  );
}

Future<void> _pumpDaftarApp(WidgetTester tester) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(() async {
    await database.close();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => database),
        appSettingsProvider.overrideWith(
          (ref) => Stream<AppSettings>.value(
            const AppSettings(hasSeenOnboarding: true),
          ),
        ),
        ledgersProvider.overrideWith(
          (ref) => Stream<List<domain.Ledger>>.value(const <domain.Ledger>[]),
        ),
        globalBalancesProvider.overrideWith(
          (ref) => Stream<List<domain.ContactBalance>>.value(
            const <domain.ContactBalance>[],
          ),
        ),
      ],
      child: const DaftarApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1200));
}
