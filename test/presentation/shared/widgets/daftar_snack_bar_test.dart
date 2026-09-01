import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Khazna snack uses themed SnackBar, not a default Material bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showDaftarSnackBar(
                    context: context,
                    message: AppLocalizations.of(context)!.collectionsDeskCopied,
                  );
                },
                child: const Text('copy'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('copy'));
    await tester.pumpAndSettle();

    expect(find.text('Reminder copied'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.elevation, 0);
  });
}
