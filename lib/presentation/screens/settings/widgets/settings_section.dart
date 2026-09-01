import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Uppercase micro-type section label for settings zones.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.spacingXs,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Hairline divider inside a zero-padded BentoBlock dock.
class SettingsBentoDivider extends StatelessWidget {
  const SettingsBentoDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.spacingMd +
            AppDimensions.iconSmall +
            2 +
            AppDimensions.spacingMd,
      ),
      child: Divider(
        height: AppDimensions.dividerThickness,
        thickness: AppDimensions.dividerThickness,
        color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
      ),
    );
  }
}

/// Compact grid-cell navigation tile for preference bento blocks.
class SettingsCompactNavCell extends StatelessWidget {
  const SettingsCompactNavCell({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: AppDimensions.iconSmall + 2,
          color: inkSecondary,
        ),
        const Gap(AppDimensions.spacingXs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: inkSecondary,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(2),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
