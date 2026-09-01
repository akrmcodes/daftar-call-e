import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

class ArchivedBadgeChip extends StatelessWidget {
  const ArchivedBadgeChip({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface3 : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(
          color: AppColors.lapis400.withValues(alpha: 0.35),
          width: AppDimensions.dividerThickness,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingXs,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 11,
              color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
