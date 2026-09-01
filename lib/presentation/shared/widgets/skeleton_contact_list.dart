import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/presentation/shared/widgets/daftar_shimmer.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shimmer skeleton for minimalist contact account cards (zero avatar).
class SkeletonContactList extends StatelessWidget {
  const SkeletonContactList({
    super.key,
    this.itemCount = 6,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusMd,
      cornerSmoothing: 0.6,
    );
    final cardColor = isDark ? AppColors.surface2 : AppColors.surface1Light;

    return DaftarShimmer(
      child: Column(
        children: List.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppDimensions.spacingMd,
            ),
            child: ClipSmoothRect(
              radius: squircleRadius,
              child: Container(
                height: 68,
                decoration: ShapeDecoration(
                  color: cardColor,
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
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.listTilePaddingH,
                  vertical: AppDimensions.listTilePaddingV,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Bone(
                            width: MediaQuery.sizeOf(context).width * 0.42,
                            height: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Bone(
                            width: MediaQuery.sizeOf(context).width * 0.28,
                            height: 10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    Bone(
                      width: 80,
                      height: 28,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSm,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
