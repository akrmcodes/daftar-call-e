import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/collections_desk_rail_card.dart';
import 'package:flutter/cupertino.dart';
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
    expect(find.byType(CupertinoSwitch), findsOneWidget);
  });

  testWidgets('skipped subtitle is fully visible when rail is off', (tester) async {
    const skipped =
        'Skipped — No outbound calls will be placed';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CollectionsDeskRailCard(
              title: 'Voice calls',
              subtitle: skipped,
              value: false,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text(skipped), findsOneWidget);
    final subtitleBox = tester.getRect(find.text(skipped));
    final titleBox = tester.getRect(find.text('Voice calls'));
    expect(subtitleBox.top, greaterThanOrEqualTo(titleBox.bottom));
    expect(subtitleBox.height, greaterThan(16));
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

    await tester.tap(find.byType(CupertinoSwitch));
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

    final switchFinder = find.byType(CupertinoSwitch);
    final switchWidget = tester.widget<CupertinoSwitch>(switchFinder);
    expect(switchWidget.onChanged, isNull);
    expect(toggled, isFalse);
  });
}
