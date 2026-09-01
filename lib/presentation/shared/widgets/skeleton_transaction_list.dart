import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/presentation/shared/widgets/daftar_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Shimmer skeleton for contact detail transaction rows.
class SkeletonTransactionList extends StatelessWidget {
  const SkeletonTransactionList({
    super.key,
    this.itemCount = 5,
    this.horizontalPadding = AppDimensions.pagePaddingH,
  });

  final int itemCount;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return DaftarShimmer(
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: horizontalPadding,
          vertical: AppDimensions.spacingMd,
        ),
        child: Column(
          children: List.generate(itemCount, (index) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppDimensions.spacingLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusSm,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(
                          width: MediaQuery.sizeOf(context).width * 0.38,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Bone(
                          width: MediaQuery.sizeOf(context).width * 0.24,
                          height: 10,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Bone(
                        width: 60,
                        height: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 4),
                      Bone(
                        width: 30,
                        height: 10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
