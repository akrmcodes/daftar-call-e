import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMark(
    WidgetTester tester, {
    required ThemeData theme,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: const Scaffold(
          body: DaftarBrandMark(),
        ),
      ),
    );
  }

  testWidgets('renders the on-dark SVG in dark theme', (tester) async {
    await pumpMark(tester, theme: ThemeData.dark());

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg, isNotNull);
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      DaftarBrandMark.onDarkAsset,
    );
    expect(find.bySemanticsLabel('دفتر'), findsOneWidget);
  });

  testWidgets('renders the on-light SVG in light theme', (tester) async {
    await pumpMark(tester, theme: ThemeData.light());

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      (svg.bytesLoader as SvgAssetLoader).assetName,
      DaftarBrandMark.onLightAsset,
    );
  });
}
