import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/settings/security/lock_timeout_option.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Pill grid for auto-lock timeout presets.
class SecurityTimeoutSelector extends StatelessWidget {
  const SecurityTimeoutSelector({
    required this.selectedSeconds,
    required this.onSelected,
    super.key,
  });

  final int selectedSeconds;
  final ValueChanged<int> onSelected;

  String _label(AppLocalizations l10n, int seconds) {
    return switch (seconds) {
      LockTimeoutOption.immediately => l10n.securityTimeoutImmediate,
      LockTimeoutOption.oneMinute => l10n.securityTimeoutOneMinute,
      LockTimeoutOption.fiveMinutes => l10n.securityTimeoutFiveMinutes,
      LockTimeoutOption.fifteenMinutes => l10n.securityTimeoutFifteenMinutes,
      _ => l10n.securityTimeoutOneMinute,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.securityTimeoutTitle,
          style: AppTextStyles.titleSmall.copyWith(
            color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingXxs),
        Text(
          l10n.securityTimeoutSubtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: inkSecondary,
            height: 1.4,
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppDimensions.spacingSm;
            final itemWidth = (constraints.maxWidth - gap) / 2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final seconds in LockTimeoutOption.values)
                  SizedBox(
                    width: itemWidth,
                    child: _TimeoutPill(
                      label: _label(l10n, seconds),
                      isActive: selectedSeconds == seconds,
                      onTap: () {
                        unawaited(HapticService.selection());
                        onSelected(seconds);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimeoutPill extends StatelessWidget {
  const _TimeoutPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          height: AppDimensions.minTapTarget,
          alignment: AlignmentDirectional.center,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.surface4 : AppColors.surface2Light)
                : (isDark ? AppColors.surface3 : AppColors.surface2Light),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: isActive
                ? Border.all(
                    color: AppColors.lapis400.withValues(alpha: 0.3),
                    width: AppDimensions.dividerThickness,
                  )
                : Border.all(
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.borderSubtleLight,
                    width: AppDimensions.dividerThickness,
                  ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isActive ? inkPrimary : inkSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
