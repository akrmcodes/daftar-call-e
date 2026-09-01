import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Fake-glass panel with center-facing specular rim — no [BackdropFilter].
///
/// Used for Closing Agent idle satellites. See `docs/design_system.md` §5.6.
class KhaznaSpecularPanel extends StatefulWidget {
  const KhaznaSpecularPanel({
    required this.child,
    super.key,
    this.onTap,
    this.padding,
    this.lightSourceAlignment = const Alignment(0, -0.15),
    this.shape = KhaznaSpecularPanelShape.rounded,
    this.maxWidth,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Alignment lightSourceAlignment;
  final KhaznaSpecularPanelShape shape;
  final double? maxWidth;

  @override
  State<KhaznaSpecularPanel> createState() => _KhaznaSpecularPanelState();
}

enum KhaznaSpecularPanelShape {
  rounded,
  pill,
}

class _KhaznaSpecularPanelState extends State<KhaznaSpecularPanel> {
  bool _pressed = false;

  SmoothBorderRadius get _squircleRadius {
    final radius = widget.shape == KhaznaSpecularPanelShape.pill
        ? AppDimensions.radiusCircular
        : AppDimensions.radiusMd;
    return SmoothBorderRadius(
      cornerRadius: radius,
      cornerSmoothing: 0.6,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark ? AppColors.glassBorder : AppColors.glassBorderLight;
    final specularRazor =
        isDark ? AppColors.specularRazorDark : AppColors.specularRazorLight;
    final fresnelSheen = isDark
        ? const Color(0x05FFFFFF)
        : const Color(0x04FFFFFF);
    final padding = widget.padding ??
        const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        );

    Widget panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth ?? double.infinity,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(borderRadius: _squircleRadius),
          shadows: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
        ),
        child: ClipSmoothRect(
          radius: _squircleRadius,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: glassFill),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        fresnelSheen,
                        Colors.transparent,
                      ],
                      stops: const [0, 0.35],
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                height: AppDimensions.dividerThickness,
                child: ColoredBox(color: specularRazor),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SpecularRimPainter(
                    borderRadius: _squircleRadius,
                    lightSourceAlignment: widget.lightSourceAlignment,
                    isDark: isDark,
                    glassBorder: glassBorder,
                  ),
                ),
              ),
              Padding(padding: padding, child: widget.child),
            ],
          ),
        ),
      ),
    );

    panel = AnimatedScale(
      scale: _pressed && widget.onTap != null ? 0.97 : 1,
      duration: AppDimensions.animationFast,
      curve: Curves.easeOutCubic,
      child: panel,
    );

    if (widget.onTap != null) {
      panel = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          unawaited(HapticService.selection());
          widget.onTap?.call();
        },
        child: panel,
      );
    }

    return panel;
  }
}

class _SpecularRimPainter extends CustomPainter {
  _SpecularRimPainter({
    required this.borderRadius,
    required this.lightSourceAlignment,
    required this.isDark,
    required this.glassBorder,
  });

  final SmoothBorderRadius borderRadius;
  final Alignment lightSourceAlignment;
  final bool isDark;
  final Color glassBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = SmoothRectangleBorder(borderRadius: borderRadius);
    final path = shape.getOuterPath(rect);

    final lightCenter = lightSourceAlignment.alongSize(size);
    final panelCenter = rect.center;

    final lightDir = lightCenter - panelCenter;
    final normalizedLight = lightDir.distance == 0
        ? const Offset(0, -1)
        : lightDir / lightDir.distance;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      _paintSegmentRim(canvas, metric, normalizedLight);
    }
  }

  void _paintSegmentRim(
    Canvas canvas,
    PathMetric metric,
    Offset lightDirection,
  ) {
    const step = 2.0;
    final length = metric.length;
    if (length <= 0) {
      return;
    }

    for (var distance = 0.0; distance < length; distance += step) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null) {
        continue;
      }

      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final facing = normal.dx * lightDirection.dx +
          normal.dy * lightDirection.dy;
      final t = ((facing + 1) / 2).clamp(0.0, 1.0);

      final brightAlpha = isDark ? 0.35 : 0.22;
      final dimAlpha = glassBorder.a;
      final alpha = dimAlpha + (brightAlpha - dimAlpha) * t;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = AppDimensions.dividerThickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final nextDistance = math.min(distance + step, length);
      final segment = metric.extractPath(distance, nextDistance);
      canvas.drawPath(segment, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpecularRimPainter oldDelegate) {
    return oldDelegate.lightSourceAlignment != lightSourceAlignment ||
        oldDelegate.isDark != isDark ||
        oldDelegate.glassBorder != glassBorder;
  }
}
