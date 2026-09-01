import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_fade_dot_matrix.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Confirm-grade vault shell for Closing Agent ceremony cards.
class ClosingAgentVaultChrome extends StatefulWidget {
  /// Creates vault chrome around [child].
  const ClosingAgentVaultChrome({
    required this.child,
    this.enableBreath = false,
    super.key,
  });

  /// Card content.
  final Widget child;

  /// When true (plan review, dark), breathe `glowSm`↔`glowMd` after 3s idle.
  final bool enableBreath;

  @override
  State<ClosingAgentVaultChrome> createState() => _ClosingAgentVaultChromeState();
}

class _ClosingAgentVaultChromeState extends State<ClosingAgentVaultChrome>
    with SingleTickerProviderStateMixin {
  AnimationController? _breathController;
  Timer? _breathDelay;

  @override
  void initState() {
    super.initState();
    _scheduleBreath();
  }

  @override
  void didUpdateWidget(covariant ClosingAgentVaultChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableBreath != widget.enableBreath) {
      _breathDelay?.cancel();
      _breathController?.dispose();
      _breathController = null;
      _scheduleBreath();
    }
  }

  void _scheduleBreath() {
    if (!widget.enableBreath) {
      return;
    }
    final disableAnimations = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (disableAnimations) {
      return;
    }
    _breathDelay = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      _breathController = AnimationController(
        vsync: this,
        duration: AppDimensions.animationBreath,
      );
      unawaited(_breathController!.repeat(reverse: true));
      setState(() {});
    });
  }

  @override
  void dispose() {
    _breathDelay?.cancel();
    _breathController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.6,
    );
    final glassBorder = isDark
        ? AppColors.glassBorder
        : AppColors.glassBorderLight;
    final specularRazor = isDark
        ? AppColors.specularRazorDark
        : AppColors.specularRazorLight;
    final gradientColors = isDark
        ? [AppColors.surface2, AppColors.surface0]
        : [AppColors.surface1Light, AppColors.surface0Light];

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(borderRadius: squircleRadius),
        shadows: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
      ),
      child: ClipSmoothRect(
        radius: squircleRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClosingAgentFadeDotMatrix(isDark: isDark),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: AppDimensions.dividerThickness,
              child: ColoredBox(color: specularRazor),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: SmoothRectangleBorder(
                      borderRadius: squircleRadius,
                      side: BorderSide(
                        color: glassBorder,
                        width: AppDimensions.dividerThickness,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.cardPadding),
              child: widget.child,
            ),
          ],
        ),
      ),
    );

    if (isDark && _breathController != null) {
      card = AnimatedBuilder(
        animation: _breathController!,
        builder: (context, child) {
          final t = _breathController!.value;
          final glow = BoxShadow.lerp(AppGlows.glowSm, AppGlows.glowMd, t)!;
          return DecoratedBox(
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AppDimensions.radiusLg,
                  cornerSmoothing: 0.6,
                ),
              ),
              shadows: [glow],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }
}
