import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/presentation/shared/widgets/daftar_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shimmer skeleton for the home ledger grid tiles.
class SkeletonLedgerGrid extends StatelessWidget {
  const SkeletonLedgerGrid({
    super.key,
    this.itemCount = 4,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surface2 : AppColors.surface1Light;

    return DaftarShimmer(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppDimensions.spacingMd,
        mainAxisSpacing: AppDimensions.spacingMd,
        childAspectRatio: 1.12,
        children: List.generate(itemCount, (index) {
          return Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: AppDimensions.dividerThickness,
              ),
            ),
            padding: const EdgeInsets.all(AppDimensions.cardPadding),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone(
                  width: 100,
                  height: 16,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                SizedBox(height: AppDimensions.spacingXxs),
                Bone(
                  width: 60,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
