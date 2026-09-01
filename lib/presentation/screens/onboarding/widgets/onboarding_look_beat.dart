import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_atoms.dart';
import 'package:daftar/presentation/shared/widgets/currency_selector.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 3 — live theme plus default currency (YER pre-selected).
class OnboardingLookBeat extends StatelessWidget {
  const OnboardingLookBeat({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.currencyCode,
    required this.onCurrencyChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String currencyCode;
  final ValueChanged<Currency> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.palette_outlined,
              title: l10n.onboardingSetupLookTitle,
              subtitle: l10n.onboardingSetupLookBody,
            ),
            const Gap(AppDimensions.spacing4xl),
            Container(
              padding: const EdgeInsetsDirectional.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight,
                  width: AppDimensions.dividerThickness,
                ),
              ),
              child: Row(
                children: [
                  ThemeSegmentPill(
                    label: l10n.onboardingSetupLookDark,
                    icon: Icons.dark_mode_rounded,
                    isActive: themeMode == ThemeMode.dark,
                    onTap: () => onThemeModeChanged(ThemeMode.dark),
                  ),
                  ThemeSegmentPill(
                    label: l10n.onboardingSetupLookLight,
                    icon: Icons.light_mode_rounded,
                    isActive: themeMode == ThemeMode.light,
                    onTap: () => onThemeModeChanged(ThemeMode.light),
                  ),
                  ThemeSegmentPill(
                    label: l10n.onboardingSetupLookSystem,
                    icon: Icons.contrast_rounded,
                    isActive: themeMode == ThemeMode.system,
                    onTap: () => onThemeModeChanged(ThemeMode.system),
                  ),
                ],
              ),
            ),
            const Gap(AppDimensions.spacing5xl),
            Text(
              l10n.onboardingSetupCurrencyLabel,
              style: AppTextStyles.labelMedium.copyWith(color: inkMuted),
            ),
            const Gap(AppDimensions.spacingMd),
            CurrencySelector(
              currencies: BuiltInCurrencies.all,
              selectedCurrencyCode: currencyCode,
              onChanged: onCurrencyChanged,
            ),
          ],
        ),
      ),
    );
  }
}
