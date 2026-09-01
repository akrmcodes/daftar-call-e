import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:daftar/presentation/screens/premium/widgets/activation_code_formatter.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_logo_seal.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Beat 6 — Pro branding showcase + optional activation code.
class OnboardingProBeat extends StatelessWidget {
  const OnboardingProBeat({
    required this.expanded,
    required this.onToggleExpanded,
    required this.codeController,
    required this.errorMessage,
    required this.storeName,
    required this.hasLogo,
    required this.logoPath,
    required this.profile,
    required this.loadLogoBytes,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final TextEditingController codeController;
  final String? errorMessage;
  final String storeName;
  final bool hasLogo;
  final String? logoPath;
  final MerchantProfile? profile;
  final Future<Uint8List?> Function(String path) loadLogoBytes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.workspace_premium_outlined,
              title: l10n.onboardingSetupProTitle,
              subtitle: l10n.onboardingSetupProBrandingSubtitle,
            ),
            const Gap(AppDimensions.spacingXxl),
            Center(
              child: StoreLogoSeal(
                diameter: 88,
                isDark: isDark,
                hasLogo: hasLogo,
                logoPath: logoPath,
                profile: profile,
                loadLogoBytes: loadLogoBytes,
              ),
            ),
            const Gap(AppDimensions.spacingMd),
            Text(
              storeName.trim().isEmpty
                  ? l10n.onboardingSetupProStoreFallback
                  : storeName.trim(),
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingXxl),
            DaftarCard(
              padding: const EdgeInsetsDirectional.all(
                AppDimensions.cardPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProFeatureRow(
                    icon: Icons.picture_as_pdf_outlined,
                    label: l10n.tierFeatureBrandedPdf,
                    ink: inkPrimary,
                  ),
                  const Gap(AppDimensions.spacingMd),
                  _ProFeatureRow(
                    icon: Icons.storefront_outlined,
                    label: l10n.tierFeatureStoreBranding,
                    ink: inkPrimary,
                  ),
                  const Gap(AppDimensions.spacingMd),
                  _ProFeatureRow(
                    icon: Icons.archive_outlined,
                    label: l10n.tierFeatureLedgerArchiving,
                    ink: inkPrimary,
                  ),
                ],
              ),
            ),
            const Gap(AppDimensions.spacingXxl),
            Text(
              l10n.onboardingSetupProHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
            ),
            const Gap(AppDimensions.spacingMd),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey<String>('onboarding-pro-expander'),
                onTap: () {
                  unawaited(HapticService.selection());
                  onToggleExpanded();
                },
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: AppDimensions.spacingMd,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: inkPrimary,
                      ),
                      const Gap(AppDimensions.spacingSm),
                      Expanded(
                        child: Text(
                          l10n.onboardingSetupProExpander,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: inkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) ...[
              const Gap(AppDimensions.spacingMd),
              DaftarTextField(
                key: const ValueKey<String>('onboarding-pro-code'),
                controller: codeController,
                label: l10n.activationCodeHint,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
                  ActivationCodeFormatter(),
                ],
                errorText: errorMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  const _ProFeatureRow({
    required this.icon,
    required this.label,
    required this.ink,
  });

  final IconData icon;
  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimensions.iconMedium, color: ink),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: ink, height: 1.45),
          ),
        ),
      ],
    );
  }
}
