import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_rail_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows title, subtitle, and switch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CollectionsDeskRailCard(
            title: 'Voice calls',
            subtitle: '1 scheduled call (Mohamed)',
            value: true,
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Voice calls'), findsOneWidget);
    expect(find.text('1 scheduled call (Mohamed)'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('selected card uses DaftarCard isSelected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionsDeskRailCard(
            title: 'Voice calls',
            subtitle: 'On',
            value: true,
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final card = tester.widget<DaftarCard>(find.byType(DaftarCard));
    expect(card.isSelected, isTrue);
  });

  testWidgets('toggle invokes onChanged', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionsDeskRailCard(
            title: 'Email statements',
            subtitle: 'Off',
            value: false,
            enabled: true,
            onChanged: (next) => toggled = next,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(toggled, isTrue);
  });

  testWidgets('disabled switch does not toggle', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionsDeskRailCard(
            title: 'Email statements',
            subtitle: 'Off',
            value: false,
            enabled: false,
            onChanged: (next) => toggled = next,
          ),
        ),
      ),
    );

    final switchFinder = find.byType(Switch);
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.onChanged, isNull);
    expect(toggled, isFalse);
  });
}
