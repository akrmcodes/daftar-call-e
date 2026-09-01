import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_atoms.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Khazna Vault hero for security posture — dual rings (PIN inner, biometric outer).
class SecurityVaultHero extends StatelessWidget {
  const SecurityVaultHero({
    required this.isAppLockEnabled,
    required this.hasPin,
    required this.isBiometricEnabled,
    required this.biometricsAvailable,
    required this.selectedTimeoutLabel,
    super.key,
  });

  final bool isAppLockEnabled;
  final bool hasPin;
  final bool isBiometricEnabled;
  final bool biometricsAvailable;
  final String selectedTimeoutLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final pinActive = isAppLockEnabled && hasPin;
    final biometricActive = pinActive && isBiometricEnabled;

    final pinProgress = pinActive ? 1.0 : 0.0;
    final biometricProgress = biometricActive
        ? 1.0
        : (pinActive && biometricsAvailable ? 0.45 : 0.0);

    final pinColor = pinActive ? AppColors.payment : AppColors.warning;
    final biometricColor = biometricActive
        ? AppColors.payment
        : (biometricsAvailable && pinActive
            ? AppColors.warning
            : inkMuted);

    final fullySecured = pinActive && biometricActive;
    final centerLabel = fullySecured
        ? '✓'
        : (pinActive ? '◐' : '!');
    final centerColor = fullySecured
        ? AppColors.payment
        : (pinActive ? AppColors.warning : AppColors.warning);

    final (statusTitle, statusSubtitle) = switch ((pinActive, biometricActive)) {
      (true, true) => (
          l10n.securityStatusProtected,
          l10n.securityStatusProtectedSubtitle,
        ),
      (true, false) => (
          l10n.securityStatusPinOnly,
          l10n.securityStatusPinOnlySubtitle,
        ),
      _ => (
          l10n.securityStatusUnprotected,
          l10n.securityStatusUnprotectedSubtitle,
        ),
    };

    return FadeSlideTransition(
      duration: AppDimensions.animationSlow,
      child: DaftarCard(
        variant: DaftarCardVariant.hero,
        padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: inkPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(AppDimensions.spacingXxs),
                      Text(
                        statusSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkSecondary,
                          height: 1.45,
                        ),
                      ),
                      if (pinActive) ...[
                        const Gap(AppDimensions.spacingSm),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: inkMuted,
                            ),
                            const Gap(AppDimensions.spacingXxs),
                            Flexible(
                              child: Text(
                                selectedTimeoutLabel,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: inkMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(AppDimensions.spacingLg),
                VaultHealthRings(
                    localProgress: pinProgress,
                    cloudProgress: biometricProgress,
                    localColor: pinColor,
                    cloudColor: biometricColor,
                    centerLabel: centerLabel,
                    centerColor: centerColor,
                    size: 88,
                    outerStrokeWidth: 4.5,
                    innerStrokeWidth: 4.5,
                    showLegend: true,
                    localLegend: l10n.securityHeroPinRing,
                    cloudLegend: l10n.securityHeroBiometricRing,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
