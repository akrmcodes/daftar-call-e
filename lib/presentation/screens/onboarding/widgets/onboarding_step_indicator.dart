import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:flutter/material.dart';

/// Lapis-border active dot; monochrome fill. Never a lapis fill.
class OnboardingStepIndicator extends StatelessWidget {
  const OnboardingStepIndicator({
    required this.pageCount,
    required this.currentIndex,
    super.key,
  });

  final int pageCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final inactiveColor =
        isDark ? AppColors.surface5 : AppColors.surface4Light;
    const dotSize = AppDimensions.spacingSm;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pageCount; i++) ...[
          if (i > 0) const SizedBox(width: AppDimensions.spacingXs),
          AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : AppDimensions.animationFast,
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == currentIndex
                  ? (isDark ? AppColors.surface2 : AppColors.surface1Light)
                  : inactiveColor,
              border: i == currentIndex
                  ? Border.all(
                      color: AppColors.lapis400,
                      width: AppDimensions.dividerThickness,
                    )
                  : null,
              boxShadow: i == currentIndex ? AppGlows.haloXs : null,
            ),
          ),
        ],
      ],
    );
  }
}
