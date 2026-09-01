import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 2 — Arabic or English. Autonyms stay stable across locale flips.
class OnboardingLanguageBeat extends StatelessWidget {
  const OnboardingLanguageBeat({
    required this.selectedLanguageCode,
    required this.onSelected,
    super.key,
  });

  final String selectedLanguageCode;
  final ValueChanged<Locale> onSelected;

  static const arabicAutonym = 'العربية';
  static const englishAutonym = 'English';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = selectedLanguageCode.toLowerCase() == 'ar' ? 'ar' : 'en';

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.translate_rounded,
              title: l10n.onboardingSetupLanguageTitle,
              subtitle: l10n.onboardingSetupLanguageBody,
            ),
            const Gap(AppDimensions.spacing4xl),
            _LanguageCard(
              key: const ValueKey<String>('onboarding-language-ar'),
              autonym: arabicAutonym,
              semanticsLabel: l10n.arabic,
              isSelected: selected == 'ar',
              textDirection: TextDirection.rtl,
              onTap: () => onSelected(const Locale('ar')),
            ),
            const Gap(AppDimensions.spacingLg),
            _LanguageCard(
              key: const ValueKey<String>('onboarding-language-en'),
              autonym: englishAutonym,
              semanticsLabel: l10n.english,
              isSelected: selected == 'en',
              textDirection: TextDirection.ltr,
              onTap: () => onSelected(const Locale('en')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.autonym,
    required this.semanticsLabel,
    required this.isSelected,
    required this.textDirection,
    required this.onTap,
    super.key,
  });

  final String autonym;
  final String semanticsLabel;
  final bool isSelected;
  final TextDirection textDirection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      child: DaftarCard(
        variant: DaftarCardVariant.selectable,
        isSelected: isSelected,
        onTap: onTap,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingXl,
          vertical: AppDimensions.spacingXxl,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            autonym,
            textAlign: TextAlign.center,
            textDirection: textDirection,
            style: AppTextStyles.headlineMedium.copyWith(color: inkPrimary),
          ),
        ),
      ),
    );
  }
}
