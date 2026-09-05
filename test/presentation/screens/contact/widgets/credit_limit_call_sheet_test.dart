import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/contact/widgets/credit_limit_call_sheet.dart';
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
    await tester.pumpAndSettle();

    expect(find.text('Prepare the call'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.textContaining('A promise is not a payment'), findsOneWidget);

    await tester.tap(find.text('Prepare the call'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);
  });
}
