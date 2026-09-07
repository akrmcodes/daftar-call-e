import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/contact/widgets/credit_limit_call_sheet.dart';
import 'package:daftar/presentation/screens/contact/widgets/credit_limit_horizon_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Prepare the call returns true', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var accepted = false;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    accepted = await CreditLimitCallSheet.show(
                      context,
                      contactName: 'Ahmed',
                      outstandingMinor: 150000,
                      creditLimitMinor: 100000,
                      currencyCode: 'YER',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Prepare the call'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.textContaining('A promise is not a payment'), findsNothing);

    await tester.tap(find.text('Prepare the call'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(accepted, isTrue);
  });

  testWidgets('Not now returns false', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var accepted = true;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    accepted = await CreditLimitCallSheet.show(
                      context,
                      contactName: 'Ahmed',
                      outstandingMinor: 150000,
                      creditLimitMinor: 100000,
                      currencyCode: 'YER',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Not now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(accepted, isFalse);
  });

  testWidgets('sheet does not overflow while viewInsets animate', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overflowErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflowErrors.add(details);
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await CreditLimitCallSheet.show(
                      context,
                      contactName: 'Ahmed',
                      outstandingMinor: 150000,
                      creditLimitMinor: 100000,
                      currencyCode: 'YER',
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();

    // Simulate keyboard still open when the sheet presents.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Keyboard finishes hiding.
    tester.view.viewInsets = FakeViewPadding.zero;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CreditLimitHorizonGlow), findsOneWidget);
    expect(overflowErrors, isEmpty);
  });
}
