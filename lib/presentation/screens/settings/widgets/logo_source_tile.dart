import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Source picker row for logo camera / gallery selection.
class LogoSourceTile extends StatelessWidget {
  const LogoSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.surface3 : AppColors.surface2Light,
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(
          cornerRadius: AppDimensions.radiusMd,
          cornerSmoothing: 0.6,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingMd,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDark
                    ? AppColors.inkSecondary
                    : AppColors.inkSecondaryLight,
              ),
              const Gap(AppDimensions.spacingMd),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark
                        ? AppColors.inkPrimary
                        : AppColors.inkPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
