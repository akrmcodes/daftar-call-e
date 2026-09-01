import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Solid opaque hero card — premium quick-settings container.
///
/// Replaces brittle glassmorphism with a stable Khazna Float surface:
/// squircle clip, subtle border, inner top highlight, 24dp padding.
///
/// In dark mode, the top highlight gently breathes (12%–35% white alpha)
/// on a 2.5s sine cadence. Animation is isolated to [_BreathingTopHighlight]
/// so the card layout tree never rebuilds from the controller tick.
class HeroBentoCard extends StatefulWidget {
  const HeroBentoCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsetsDirectional.all(AppDimensions.spacingXxl),
    this.cornerRadius = AppDimensions.radiusXl,
    this.cornerSmoothing = 0.65,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double cornerRadius;
  final double cornerSmoothing;

  static const Duration _breathDuration = Duration(milliseconds: 2500);

  @override
  State<HeroBentoCard> createState() => _HeroBentoCardState();
}

class _HeroBentoCardState extends State<HeroBentoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final Animation<double> _breathAnim;

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(
      vsync: this,
      duration: HeroBentoCard._breathDuration,
    );
    _breathAnim = Tween<double>(begin: 0.12, end: 0.35).animate(
      CurvedAnimation(
        parent: _breathCtrl,
        curve: Curves.easeInOutSine,
      ),
    );
    unawaited(_breathCtrl.repeat(reverse: true));
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    super.dispose();
  }

  void _syncBreathForBrightness(bool isDark) {
    if (!isDark && _breathCtrl.isAnimating) {
      _breathCtrl.stop();
    } else if (isDark && !_breathCtrl.isAnimating) {
      unawaited(_breathCtrl.repeat(reverse: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _syncBreathForBrightness(isDark);

    final smoothRadius = SmoothBorderRadius(
      cornerRadius: widget.cornerRadius,
      cornerSmoothing: widget.cornerSmoothing,
    );

    final heroShadow = isDark
        ? [...AppGlows.haloXs, ...AppGlows.khazaFloat]
        : AppGlows.shadowElevated;

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: heroShadow,
        borderRadius: BorderRadius.circular(widget.cornerRadius),
      ),
      child: ClipSmoothRect(
        radius: smoothRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface3 : AppColors.surface1Light,
            border: Border.all(
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.borderSubtleLight,
              width: AppDimensions.dividerThickness,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDark)
                AnimatedBuilder(
                  animation: _breathAnim,
                  builder: (context, _) => _BreathingTopHighlight(
                    alpha: _breathAnim.value,
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
    );
  }
}

/// Isolated top-edge light catch — sole rebuild target for the breath tick.
/// Horizontal gradient fades to transparent before squircle corners clip.
class _BreathingTopHighlight extends StatelessWidget {
  const _BreathingTopHighlight({required this.alpha});

  final double alpha;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: alpha),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
      child: const SizedBox(
        height: 1.5,
        width: double.infinity,
      ),
    );
  }
}
