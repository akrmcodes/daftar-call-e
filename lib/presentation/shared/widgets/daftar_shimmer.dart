import 'package:daftar/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Wraps [child] with [Skeletonizer] shimmer using Khazna v3 shimmer tokens.
class DaftarShimmer extends StatelessWidget {
  const DaftarShimmer({
    required this.child,
    super.key,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor:
            isDark ? AppColors.shimmerBase : AppColors.shimmerBaseLight,
        highlightColor: isDark
            ? AppColors.shimmerHighlight
            : AppColors.shimmerHighlightLight,
        duration: const Duration(milliseconds: 1400),
      ),
      child: child,
    );
  }
}
