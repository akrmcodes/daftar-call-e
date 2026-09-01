import 'package:daftar/app/theme/app_theme.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer createBalanceCardTestContainer(AppDatabase database) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => database),
      appSettingsProvider.overrideWith(
        (ref) => Stream<AppSettings>.value(const AppSettings()),
      ),
    ],
  );
}

/// Pumps [BalanceCard] in a minimal themed shell.
///
/// [appSettingsProvider] must be overridden: an empty in-memory DB never emits
/// on `watchSettings()`, which can stall providers when the widget tree is live.
Future<void> pumpBalanceCardTestApp(
  WidgetTester tester, {
  required AppDatabase database,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => database),
        appSettingsProvider.overrideWith(
          (ref) => Stream<AppSettings>.value(const AppSettings()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: BalanceCard(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

AppDatabase createBalanceCardTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
