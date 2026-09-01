import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_beat.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Beat 5 — Google is recommended and skippable; failure stays here.
class OnboardingGoogleBeat extends StatelessWidget {
  const OnboardingGoogleBeat({
    required this.errorMessage,
    required this.signedInNeedsGrant,
    required this.grantErrorMessage,
    super.key,
  });

  final String? errorMessage;
  final bool signedInNeedsGrant;
  final String? grantErrorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return OnboardingBeatMotion(
      child: OnboardingBeatFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OnboardingBeatHeader(
              icon: Icons.cloud_upload_outlined,
              title: l10n.onboardingSetupGoogleTitle,
              subtitle: l10n.onboardingSetupGoogleBody,
            ),
            const Gap(AppDimensions.spacing4xl),
            OnboardingBeatLine(
              icon: Icons.smartphone_outlined,
              text: l10n.accountManagementTrustLocalData,
            ),
            const Gap(AppDimensions.spacingSm),
            OnboardingBeatLine(
              icon: Icons.folder_special_outlined,
              text: l10n.accountManagementTrustDriveScope,
            ),
            const Gap(AppDimensions.spacingSm),
            OnboardingBeatLine(
              icon: Icons.lock_outline_rounded,
              text: l10n.backupDriveInviteBody,
            ),
            if (signedInNeedsGrant) ...[
              const Gap(AppDimensions.spacingXl),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.35),
                    width: AppDimensions.dividerThickness,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(
                    AppDimensions.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.key_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const Gap(AppDimensions.spacingSm),
                          Expanded(
                            child: Text(
                              l10n.onboardingSetupGoogleSignedIn,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: inkPrimary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppDimensions.spacingSm),
                      Text(
                        l10n.backupDriveOfflineGrantMissing,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.inkSecondary
                              : AppColors.inkSecondaryLight,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const Gap(AppDimensions.spacingLg),
              Text(
                key: const ValueKey<String>('onboarding-google-error'),
                errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
            if (grantErrorMessage != null) ...[
              const Gap(AppDimensions.spacingLg),
              Text(
                key: const ValueKey<String>('onboarding-google-grant-error'),
                grantErrorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
