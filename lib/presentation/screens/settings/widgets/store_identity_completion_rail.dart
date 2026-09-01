import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Three-node checklist — store name, phone, and logo completion.
class StoreIdentityCompletionRail extends StatelessWidget {
  const StoreIdentityCompletionRail({
    required this.hasName,
    required this.hasPhone,
    required this.hasLogo,
    super.key,
    this.compact = false,
  });

  final bool hasName;
  final bool hasPhone;
  final bool hasLogo;
  final bool compact;

  bool get _isComplete => hasName && hasPhone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    final statusLabel = _isComplete
        ? l10n.merchantBrandingIdentityComplete
        : l10n.merchantBrandingIdentityIncomplete;
    final statusColor = _isComplete ? AppColors.payment : inkSecondary;

    final steps = [
      (l10n.merchantBrandingStoreName, hasName, Icons.storefront_outlined),
      (l10n.merchantBrandingStepPhone, hasPhone, Icons.call_outlined),
      (l10n.merchantBrandingStepLogo, hasLogo, Icons.image_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            l10n.merchantBrandingCompletionTitle,
            style: AppTextStyles.labelMedium.copyWith(
              color: inkMuted,
              letterSpacing: 0.4,
            ),
          ),
          const Gap(AppDimensions.spacingSm),
        ],
        Row(
          children: [
            Icon(
              _isComplete
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: AppDimensions.iconSmall,
              color: statusColor,
            ),
            const Gap(AppDimensions.spacingXs),
            Expanded(
              child: Text(
                statusLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingMd),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: AppDimensions.dividerThickness,
                    margin: const EdgeInsetsDirectional.only(
                      bottom: AppDimensions.spacingLg,
                    ),
                    color: (steps[i].$2 || steps[i - 1].$2)
                        ? AppColors.payment.withValues(alpha: 0.5)
                        : (isDark
                            ? AppColors.borderSubtle
                            : AppColors.borderSubtleLight),
                  ),
                ),
              _StepPill(
                label: steps[i].$1,
                icon: steps[i].$3,
                isComplete: steps[i].$2,
                isDark: isDark,
                inkPrimary: inkPrimary,
                inkMuted: inkMuted,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.label,
    required this.icon,
    required this.isComplete,
    required this.isDark,
    required this.inkPrimary,
    required this.inkMuted,
  });

  final String label;
  final IconData icon;
  final bool isComplete;
  final bool isDark;
  final Color inkPrimary;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final ringColor = isComplete
        ? AppColors.payment.withValues(alpha: 0.6)
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surface,
            border: Border.all(color: ringColor),
          ),
          alignment: Alignment.center,
          child: Icon(
            isComplete ? Icons.check_rounded : icon,
            size: 16,
            color: isComplete ? AppColors.payment : inkMuted,
          ),
        ),
        const Gap(AppDimensions.spacingXxs),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: isComplete ? inkPrimary : inkMuted,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
