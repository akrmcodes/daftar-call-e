import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 4 — optional store name; logo picker only when Pro.
class OnboardingStoreBeat extends StatelessWidget {
  const OnboardingStoreBeat({
    required this.nameController,
    required this.isPro,
    required this.onPickLogo,
    this.pendingLogoName,
    super.key,
  });

  final TextEditingController nameController;
  final bool isPro;
  final VoidCallback onPickLogo;
  final String? pendingLogoName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.storefront_outlined,
              title: l10n.onboardingSetupStoreTitle,
              subtitle: l10n.onboardingSetupStoreBody,
            ),
            Gap(
              keyboardOpen
                  ? AppDimensions.spacingXxl
                  : AppDimensions.spacing4xl,
            ),
            DaftarTextField(
              controller: nameController,
              label: l10n.merchantBrandingStoreName,
              hint: l10n.onboardingSetupStoreNameHint,
              prefixIcon: Icons.storefront_outlined,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
            ),
            const Gap(AppDimensions.spacingXxl),
            if (isPro)
              DaftarButton(
                key: const ValueKey<String>('onboarding-store-logo'),
                label: pendingLogoName == null
                    ? l10n.merchantBrandingUploadLogo
                    : pendingLogoName!,
                variant: DaftarButtonVariant.secondary,
                icon: Icons.add_photo_alternate_outlined,
                isExpanded: true,
                onPressed: onPickLogo,
              )
            else
              Text(
                l10n.onboardingSetupStoreLogoPro,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}
