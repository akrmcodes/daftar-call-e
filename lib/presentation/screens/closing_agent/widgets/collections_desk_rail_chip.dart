import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Filter-style rail toggle for Collections Desk outreach consent.
///
/// Khazna §8.7 — lapis hairline and optional glow when selected; never lapis fill.
class CollectionsDeskRailChip extends StatelessWidget {
  /// Creates a rail chip.
  const CollectionsDeskRailChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  /// Chip label (includes count).
  final String label;

  /// Whether this rail is included in the commit.
  final bool selected;

  /// False while in-flight or after call rail is committed.
  final bool enabled;

  /// Toggles local intent before the merchant commits.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedFill = isDark ? AppColors.surface4 : AppColors.surface3Light;
    final unselectedFill = isDark
        ? AppColors.surface3.withValues(alpha: 0.5)
        : AppColors.surface2Light.withValues(alpha: 0.6);
    final selectedBorder = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final unselectedBorder = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final selectedText = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final unselectedText = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final checkColor = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              unawaited(HapticService.selection());
              onToggle();
            }
          : null,
      child: DaftarTapTarget(
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: AppMotion.curveEnter,
          height: 42,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingSm,
          ),
          decoration: ShapeDecoration(
            color: selected ? selectedFill : unselectedFill,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: AppDimensions.radiusSm,
                cornerSmoothing: 0.6,
              ),
              side: BorderSide(
                color: selected ? selectedBorder : unselectedBorder,
                width: AppDimensions.dividerThickness,
              ),
            ),
            shadows: selected ? AppGlows.haloXs : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: AppDimensions.animationFast,
                curve: AppMotion.curveSpring,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: AppDimensions.animationFast,
                  curve: AppMotion.curveEnter,
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: checkColor,
                  ),
                ),
              ),
              if (selected) const SizedBox(width: AppDimensions.spacingXxs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: enabled
                        ? (selected ? selectedText : unselectedText)
                        : unselectedText.withValues(alpha: AppColors.alphaMedium),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
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
