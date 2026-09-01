import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:flutter/material.dart';

/// Vault seal ring + brand mark for Closing Agent studio scenes.
enum ClosingAgentVaultSealMode {
  /// Draw the ring once, then slow catch highlight (idle hero).
  idle,

  /// Ring complete; continuous ink sweep (clerk working).
  working,
}

/// 96dp vault seal with lapis stroke on a monochrome track.
class ClosingAgentVaultSeal extends StatefulWidget {
  const ClosingAgentVaultSeal({
    this.mode = ClosingAgentVaultSealMode.idle,
    this.size = 96,
    this.markSize = 56,
    super.key,
  });

  final ClosingAgentVaultSealMode mode;
  final double size;
  final double markSize;

  @override
  State<ClosingAgentVaultSeal> createState() => _ClosingAgentVaultSealState();
}

class _ClosingAgentVaultSealState extends State<ClosingAgentVaultSeal>
    with TickerProviderStateMixin {
  /// Continuous full-orbit catch (seamless at repeat boundary).
  static const _catchPeriod = Duration(milliseconds: 2400);

  AnimationController? _drawController;
  AnimationController? _catchController;
  bool _motionReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionReady) {
      return;
    }
    _motionReady = true;
    _startMotion();
  }

  @override
  void didUpdateWidget(ClosingAgentVaultSeal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _drawController?.dispose();
      _catchController?.dispose();
      _drawController = null;
      _catchController = null;
      _startMotion();
    }
  }

  @override
  void dispose() {
    _drawController?.dispose();
    _catchController?.dispose();
    super.dispose();
  }

  void _startMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    if (widget.mode == ClosingAgentVaultSealMode.working) {
      _catchController = AnimationController(
        vsync: this,
        duration: _catchPeriod,
      );
      unawaited(_catchController!.repeat());
      setState(() {});
      return;
    }
    _drawController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationXSlow,
    );
    unawaited(
      _drawController!.forward().then((_) {
        if (!mounted) {
          return;
        }
        unawaited(HapticService.selection());
        _catchController = AnimationController(
          vsync: this,
          duration: _catchPeriod,
        );
        unawaited(_catchController!.repeat());
        setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final drawController = _drawController;
    final catchController = _catchController;
    final isWorking = widget.mode == ClosingAgentVaultSealMode.working;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            ?drawController,
            ?catchController,
          ]),
          builder: (context, child) {
            final drawProgress = isWorking || reduceMotion || drawController == null
                ? 1.0
                : AppMotion.curveEnter.transform(drawController.value);
            final catchT = reduceMotion || catchController == null
                ? 0.0
                : catchController.value;
            final highlightPhase = catchT;
            final markOpacity = isWorking || reduceMotion || drawController == null
                ? 1.0
                : drawProgress;
            final markScale = isWorking || reduceMotion || drawController == null
                ? 1.0
                : 0.92 + 0.08 * drawProgress;

            return CustomPaint(
              painter: ClosingAgentVaultRingPainter(
                isDark: isDark,
                drawProgress: drawProgress,
                highlightPhase: highlightPhase,
              ),
              child: Center(
                child: Transform.scale(
                  scale: markScale,
                  child: Opacity(
                    opacity: markOpacity.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: DaftarBrandMark(size: widget.markSize),
        ),
      ),
    );
  }
}

/// Monochrome track + lapis stroke for the vault seal ring.
class ClosingAgentVaultRingPainter extends CustomPainter {
  const ClosingAgentVaultRingPainter({
    required this.isDark,
    required this.drawProgress,
    required this.highlightPhase,
  });

  final bool isDark;
  final double drawProgress;
  final double highlightPhase;

  static const double _sweepRadians = math.pi * 1.5;
  static const double _startRadians = -math.pi * 0.75;
  static const double _highlightSweep = 0.40;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const stroke = 1.5;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final lapisPaint = Paint()
      ..color = lapis
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawArc(rect, 0, math.pi * 2, false, trackPaint)
      ..drawArc(
        rect,
        _startRadians,
        _sweepRadians * drawProgress.clamp(0.0, 1.0),
        false,
        lapisPaint,
      );

    if (drawProgress >= 0.99 && highlightPhase > 0) {
      final highlightCenter = _startRadians + highlightPhase * math.pi * 2;
      final highlightPaint = Paint()
        ..color = lapis.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 0.35
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        highlightCenter - _highlightSweep * 0.5,
        _highlightSweep,
        false,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ClosingAgentVaultRingPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.drawProgress != drawProgress ||
        oldDelegate.highlightPhase != highlightPhase;
  }
}

/// Compact 16dp lapis arc for inline button loading (rhymes with vault seal).
class ClosingAgentVaultLoadingArc extends StatefulWidget {
  const ClosingAgentVaultLoadingArc({
    required this.color,
    super.key,
  });

  final Color color;

  static const double diameter = 16;

  @override
  State<ClosingAgentVaultLoadingArc> createState() =>
      _ClosingAgentVaultLoadingArcState();
}

class _ClosingAgentVaultLoadingArcState extends State<ClosingAgentVaultLoadingArc>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _started = true;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_controller!.repeat());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final controller = _controller;

    if (reduceMotion || controller == null) {
      return CustomPaint(
        size: const Size.square(ClosingAgentVaultLoadingArc.diameter),
        painter: _LoadingArcPainter(
          color: widget.color,
          rotation: 0,
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size.square(ClosingAgentVaultLoadingArc.diameter),
          painter: _LoadingArcPainter(
            color: widget.color,
            rotation: controller.value * math.pi * 2,
          ),
        );
      },
    );
  }
}

class _LoadingArcPainter extends CustomPainter {
  const _LoadingArcPainter({
    required this.color,
    required this.rotation,
  });

  final Color color;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect.deflate(1),
      rotation - math.pi * 0.5,
      math.pi * 1.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoadingArcPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.rotation != rotation;
  }
}
