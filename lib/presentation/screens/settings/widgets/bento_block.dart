import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Bento Grid block — the visual atom of the settings dashboard.
///
/// Every settings cell lives inside a [BentoBlock]. Provides:
/// - Squircle corners via figma_squircle.
/// - Khazna Float ambient glow (dark) / soft float shadow (light).
/// - Optional Lapis border glow for highlighted cells.
/// - Scale press micro-interaction.
class BentoBlock extends StatefulWidget {
  const BentoBlock({
    required this.child,
    super.key,
    this.onTap,
    this.lapisGlow = false,
    this.padding = const EdgeInsetsDirectional.all(AppDimensions.spacingLg),
    this.cornerRadius = AppDimensions.radiusXl,
    this.cornerSmoothing = 0.65,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// If `true`, adds a subtle Lapis 0.5px border + glowXs halo.
  /// Obeys the Lapis Law — border only, never fill.
  final bool lapisGlow;

  final EdgeInsetsGeometry padding;
  final double cornerRadius;
  final double cornerSmoothing;

  @override
  State<BentoBlock> createState() => _BentoBlockState();
}

class _BentoBlockState extends State<BentoBlock> {
  bool _pressed = false;

  SmoothBorderRadius get _radius => SmoothBorderRadius(
        cornerRadius: widget.cornerRadius,
        cornerSmoothing: widget.cornerSmoothing,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lapisBorder = widget.lapisGlow
        ? Border.all(
            color: AppColors.lapis400.withValues(alpha: 0.45),
            width: AppDimensions.dividerThickness,
          )
        : Border.all(
            color: isDark
                ? AppColors.borderSubtle
                : AppColors.borderSubtleLight,
            width: AppDimensions.dividerThickness,
          );

    final lapisShadow = widget.lapisGlow
        ? [...AppGlows.haloXs, ...(isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat)]
        : (isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat);

    final baseColor = isDark ? AppColors.surface2 : AppColors.surface1Light;
    final pressedColor = isDark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.03),
            baseColor,
          )
        : Color.alphaBlend(
            Colors.black.withValues(alpha: 0.02),
            baseColor,
          );

    final block = AnimatedScale(
      scale: _pressed ? 0.975 : 1.0,
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: lapisShadow,
          borderRadius: BorderRadius.circular(widget.cornerRadius),
        ),
        child: ClipSmoothRect(
          radius: _radius,
          child: AnimatedContainer(
            duration: AppDimensions.animationFast,
            decoration: BoxDecoration(
              color: _pressed ? pressedColor : baseColor,
              border: lapisBorder,
            ),
            child: Stack(
              children: [
                // Inner top highlight edge — Khazna depth cue
                if (isDark)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    end: 0,
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.innerTopHighlight,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: widget.padding,
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) {
      return block;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        unawaited(HapticService.buttonPress());
        widget.onTap?.call();
      },
      child: block,
    );
  }
}
