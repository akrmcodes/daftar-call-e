import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Compact row signaling the card is tappable to expand.
class BalanceCardExpandHint extends StatelessWidget {
  const BalanceCardExpandHint({
    required this.isExpanded,
    required this.collapsedLabel,
    required this.expandedLabel,
    required this.mutedColor,
    super.key,
  });

  final bool isExpanded;
  final String collapsedLabel;
  final String expandedLabel;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final label = isExpanded ? expandedLabel : collapsedLabel;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: AppDimensions.animationFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: Text(
            label,
            key: ValueKey<String>(label),
            style: AppTextStyles.bodySmall.copyWith(
              color: mutedColor,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXxs),
        AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: AppDimensions.animationMedium,
          curve: AppMotion.curveEnter,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: AppDimensions.iconSmall,
            color: mutedColor,
          ),
        ),
      ],
    );
  }
}
