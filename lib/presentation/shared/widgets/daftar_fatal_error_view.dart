import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/app/theme/app_theme.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/app_restarter.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Premium full-screen surface shown when the framework cannot build a widget.
///
/// Never exposes stack traces — reassures merchants that ledger data is safe.
class DaftarFatalErrorView extends StatelessWidget {
  const DaftarFatalErrorView({
    super.key,
    this.details,
  });

  final FlutterErrorDetails? details;

  @override
  Widget build(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final l10n = lookupAppLocalizations(locale);
    final isRtl = locale.languageCode == 'ar';
    final isDark = _resolvePreferDark(locale);

    final background =
        isDark ? AppColors.surface1 : AppColors.surface0Light;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final iconFill = isDark ? AppColors.surface3 : AppColors.surface2Light;

    final squircle = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.6,
    );

    return Theme(
      data: isDark ? AppTheme.dark : AppTheme.light,
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Material(
          color: background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.pagePaddingH,
                AppDimensions.spacing3xl,
                AppDimensions.pagePaddingH,
                AppDimensions.spacingXl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DecoratedBox(
                              decoration: ShapeDecoration(
                                color: iconFill,
                                shape: SmoothRectangleBorder(
                                  borderRadius: squircle,
                                  side: BorderSide(
                                    color: lapis.withValues(alpha: 0.35),
                                    width: AppDimensions.dividerThickness,
                                  ),
                                ),
                                shadows: [
                                  AppGlows.glowMd,
                                  if (!isDark) ...AppGlows.shadowSoft,
                                ],
                              ),
                              child: SizedBox(
                                width: 112,
                                height: 112,
                                child: Icon(
                                  Icons.shield_rounded,
                                  size: AppDimensions.iconLarge,
                                  color: lapis,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXxl),
                            Text(
                              l10n.fatalErrorTitle,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: inkPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            Text(
                              l10n.fatalErrorBody,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: inkSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  DaftarButton(
                    label: l10n.fatalErrorRestart,
                    isExpanded: true,
                    icon: Icons.refresh_rounded,
                    onPressed: AppRestarter.restart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _resolvePreferDark(Locale locale) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return platformBrightness == Brightness.dark;
  }
}
