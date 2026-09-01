import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBanner(
    WidgetTester tester, {
    required Locale locale,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return DaftarPermissionBanner(
                message: l10n.closingAgentMicPermissionDenied,
                actionLabel: actionLabel ?? l10n.closingAgentMicOpenSettings,
                onAction: onAction,
                semanticsLabel: l10n.closingAgentPermissionBannerSemantics,
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('English denied banner uses Open Settings callback', (
    tester,
  ) async {
    var taps = 0;
    await pumpBanner(
      tester,
      locale: const Locale('en'),
      onAction: () => taps++,
    );
    await tester.pump();

    expect(find.textContaining('Microphone access is off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('Arabic denied banner is RTL and not English copy', (
    tester,
  ) async {
    await pumpBanner(tester, locale: const Locale('ar'), onAction: () {});
    await tester.pump();

    expect(find.textContaining('Microphone access is off'), findsNothing);
    expect(find.textContaining('الميكروفون'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(DaftarPermissionBanner))),
      TextDirection.rtl,
    );
  });

  testWidgets('CTA is secondary DaftarButton, not a lapis fill', (
    tester,
  ) async {
    await pumpBanner(
      tester,
      locale: const Locale('en'),
      onAction: () {},
    );
    await tester.pump();

    final button = tester.widget<DaftarButton>(find.byType(DaftarButton));
    expect(button.variant, DaftarButtonVariant.secondary);

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(DaftarPermissionBanner),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(
      decoration.color == AppColors.lapis800 ||
          decoration.color == AppColors.lapis50,
      isTrue,
    );
  });

  testWidgets('hold hint has no action button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DaftarPermissionBanner(message: 'Hold to speak'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DaftarButton), findsNothing);
    expect(find.text('Hold to speak'), findsOneWidget);
  });
}
