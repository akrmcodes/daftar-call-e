import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_tokens.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Animated 0.5px lapis stroke that traces the squircle perimeter once, then
/// fades out. Fires on mount and when the parent increments its trace key.
class BalanceCardLapisTraceBorder extends StatefulWidget {
  const BalanceCardLapisTraceBorder({
    required this.isDark,
    super.key,
  });

  final bool isDark;

  @override
  State<BalanceCardLapisTraceBorder> createState() =>
      _BalanceCardLapisTraceBorderState();
}

class _BalanceCardLapisTraceBorderState extends State<BalanceCardLapisTraceBorder>
    with SingleTickerProviderStateMixin {
  static const int _tailSegments = 5;
  static const double _tailFraction = 0.15;
  static const double _fadeStartLap = 0.7;

  static final Duration _traceDuration =
      AppDimensions.animationXSlow + AppDimensions.animationSlow;

  late final AnimationController _controller;
  late final Animation<double> _lapProgress;
  late final Animation<double> _fadeOpacity;

  List<ui.PathMetric>? _metrics;
  double _perimeter = 0;
  Size? _cachedSize;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _traceDuration,
    );
    _lapProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
    _fadeOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          _fadeStartLap,
          1,
          curve: Curves.easeInOutSine,
        ),
      ),
    );
    _controller.addStatusListener(_onAnimationStatus);
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted && !_completed) {
        unawaited(_controller.forward());
      }
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_completed) {
      setState(() => _completed = true);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _updatePathCache(Size size, TextDirection textDirection) {
    if (_cachedSize == size) {
      return;
    }
    _cachedSize = size;
    final shape = SmoothRectangleBorder(
      borderRadius: BalanceCardTokens.squircleRadius,
      side: const BorderSide(width: AppDimensions.dividerThickness),
    );
    final path = shape.getOuterPath(
      Offset.zero & size,
      textDirection: textDirection,
    );
    _metrics = path.computeMetrics(forceClosed: true).toList();
    _perimeter = _metrics!.fold<double>(0, (sum, m) => sum + m.length);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return const SizedBox.shrink();
    }

    final textDirection = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.width > 0 && size.height > 0) {
          _updatePathCache(size, textDirection);
        }
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_perimeter <= 0 ||
                _metrics == null ||
                _fadeOpacity.value <= 0) {
              return const SizedBox.shrink();
            }
            return RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: BalanceCardLapisTracePainter(
                  metrics: _metrics!,
                  perimeter: _perimeter,
                  lapProgress: _lapProgress.value,
                  fadeOpacity: _fadeOpacity.value,
                  color: AppColors.lapisLumen,
                  useAdditiveGlow: widget.isDark,
                  tailSegments: _tailSegments,
                  tailFraction: _tailFraction,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Draws the comet head and fading tail along cached path metrics.
class BalanceCardLapisTracePainter extends CustomPainter {
  const BalanceCardLapisTracePainter({
    required this.metrics,
    required this.perimeter,
    required this.lapProgress,
    required this.fadeOpacity,
    required this.color,
    required this.useAdditiveGlow,
    required this.tailSegments,
    required this.tailFraction,
  });

  final List<ui.PathMetric> metrics;
  final double perimeter;
  final double lapProgress;
  final double fadeOpacity;
  final Color color;
  final bool useAdditiveGlow;
  final int tailSegments;
  final double tailFraction;

  static const double _headSpan = 1.5;
  static const double _tailGlowAlpha = 0.62;
  static const double _tailStrokeAlpha = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (perimeter <= 0 || fadeOpacity <= 0 || lapProgress <= 0) {
      return;
    }

    final head = lapProgress * perimeter;
    final tailLength = perimeter * tailFraction;
    final tailStart = head - tailLength;

    final metric = metrics.first;
    final contourLength = metric.length;

    final segmentLength = tailLength / tailSegments;
    for (var i = 0; i < tailSegments; i++) {
      final segStart = tailStart + segmentLength * i;
      final segEnd = tailStart + segmentLength * (i + 1);
      final t = (i + 1) / tailSegments;
      final alpha = t * fadeOpacity;

      if (useAdditiveGlow) {
        final glowPaint = _strokePaint(
          color: color.withValues(alpha: alpha * _tailGlowAlpha),
          strokeWidth: 1,
          blur: const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.25),
        );
        _drawWrappedSegment(
          canvas,
          metric,
          contourLength,
          segStart,
          segEnd,
          glowPaint,
        );
      }

      final tailPaint = _strokePaint(
        color: color.withValues(alpha: alpha * _tailStrokeAlpha),
        strokeWidth: AppDimensions.dividerThickness,
      );

      _drawWrappedSegment(
        canvas,
        metric,
        contourLength,
        segStart,
        segEnd,
        tailPaint,
      );
    }

    final headPaint = _strokePaint(
      color: color.withValues(alpha: fadeOpacity),
      strokeWidth: AppDimensions.dividerThickness,
    );

    _drawWrappedSegment(
      canvas,
      metric,
      contourLength,
      head - _headSpan,
      head,
      headPaint,
    );
  }

  Paint _strokePaint({
    required Color color,
    required double strokeWidth,
    ui.MaskFilter? blur,
  }) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color
      ..blendMode = useAdditiveGlow ? BlendMode.plus : BlendMode.srcOver
      ..maskFilter = blur;
  }

  void _drawWrappedSegment(
    Canvas canvas,
    ui.PathMetric metric,
    double contourLength,
    double start,
    double end,
    Paint paint,
  ) {
    if (start >= end) {
      return;
    }

    if (start < 0) {
      canvas
        ..drawPath(
          metric.extractPath(contourLength + start, contourLength),
          paint,
        )
        ..drawPath(metric.extractPath(0, end), paint);
      return;
    }

    if (end > contourLength) {
      canvas
        ..drawPath(metric.extractPath(start, contourLength), paint)
        ..drawPath(metric.extractPath(0, end - contourLength), paint);
      return;
    }

    canvas.drawPath(metric.extractPath(start, end), paint);
  }

  @override
  bool shouldRepaint(covariant BalanceCardLapisTracePainter oldDelegate) {
    return oldDelegate.lapProgress != lapProgress ||
        oldDelegate.fadeOpacity != fadeOpacity;
  }
}
