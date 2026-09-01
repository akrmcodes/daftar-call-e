import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/onboarding/widgets/onboarding_ledger_beat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ledger beat shows Try with Demo Store instead of suppliers', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OnboardingLedgerBeat(
            isBusy: false,
            onSelected: (_, {customName}) {},
            onTryDemoStore: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('onboarding-try-demo-store')),
      findsOneWidget,
    );
    expect(find.text('Try with Demo Store'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('onboarding-ledger-suppliers')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('onboarding-try-demo-store')),
    );
    expect(tapped, isTrue);
  });

  testWidgets('Arabic locale shows تجربة متجر افتراضي on ledger beat', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: OnboardingLedgerBeat(
            isBusy: false,
            onSelected: (_, {customName}) {},
            onTryDemoStore: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('تجربة متجر افتراضي'), findsOneWidget);
  });
}
