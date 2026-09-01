import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/presentation/shared/widgets/daftar_shimmer.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shimmer placeholder for the contact detail vault header card.
class SkeletonContactVaultCard extends StatelessWidget {
  const SkeletonContactVaultCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusXl,
      cornerSmoothing: 0.6,
    );
    final fill = isDark ? AppColors.surface2 : AppColors.surface1Light;

    return DaftarShimmer(
      child: ClipSmoothRect(
        radius: squircleRadius,
        child: Container(
          height: 132,
          decoration: ShapeDecoration(
            color: fill,
            shape: SmoothRectangleBorder(
              borderRadius: squircleRadius,
              side: BorderSide(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: AppDimensions.dividerThickness,
              ),
            ),
          ),
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXl),
          child: Row(
            children: [
              Bone(
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              const SizedBox(width: AppDimensions.spacingLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Bone(
                      width: MediaQuery.sizeOf(context).width * 0.45,
                      height: 20,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    Bone(
                      width: MediaQuery.sizeOf(context).width * 0.32,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
