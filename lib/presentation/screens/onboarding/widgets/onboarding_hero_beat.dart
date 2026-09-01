import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 1 — wordmark plus one merchant line.
class OnboardingHeroBeat extends StatelessWidget {
  const OnboardingHeroBeat({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        centerWhenShort: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DaftarBrandMark(size: 96, glow: true),
            const Gap(AppDimensions.spacing4xl),
            Text(
              l10n.onboardingSetupHeroLine,
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(color: inkPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
