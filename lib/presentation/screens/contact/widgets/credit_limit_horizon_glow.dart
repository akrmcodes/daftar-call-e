import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// In-card debt-red horizon for the credit-limit HITL sheet.
///
/// Light sits on the top edge and falls downward into the sheet. Emission is
/// clipped to the card — never a red fill, never a halo outside the radius.
class CreditLimitHorizonGlow extends StatefulWidget {
  const CreditLimitHorizonGlow({
    required this.active,
    super.key,
  });

  /// When true the crest fades in and breathes; when false it exhales out.
  final bool active;

  /// Tall enough for the downward wash to finish inside the header.
  static const double crestHeight = 128;

  @override
  State<CreditLimitHorizonGlow> createState() => _CreditLimitHorizonGlowState();
}

class _CreditLimitHorizonGlowState extends State<CreditLimitHorizonGlow>
    with TickerProviderStateMixin {
  static const Duration _fadeInDuration = AppDimensions.animationMedium;
  static const _fadeOutDuration = Duration(milliseconds: 450);
  static const _reduceMotionFade = Duration(milliseconds: 100);

  AnimationController? _visibilityController;
  AnimationController? _breathController;
  bool _dependenciesReady = false;

  bool get _reduceMotion =>
      _dependenciesReady && MediaQuery.disableAnimationsOf(context);

  Duration get _fadeIn => _reduceMotion ? _reduceMotionFade : _fadeInDuration;

  Duration get _fadeOut => _reduceMotion ? _reduceMotionFade : _fadeOutDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) {
      return;
    }
    _dependenciesReady = true;
    if (widget.active) {
      _activate();
    }
  }

  @override
  void didUpdateWidget(CreditLimitHorizonGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dependenciesReady || oldWidget.active == widget.active) {
      return;
    }
    if (widget.active) {
      _activate();
      return;
    }
    _deactivate();
  }

  void _activate() {
    _visibilityController ??= AnimationController(vsync: this);
    _visibilityController!.duration = _fadeIn;
    unawaited(_visibilityController!.forward());
    if (!_reduceMotion) {
      _breathController ??= AnimationController(
        vsync: this,
        duration: AppDimensions.animationBreath,
      );
      if (!_breathController!.isAnimating) {
        unawaited(_breathController!.repeat(reverse: true));
      }
    }
  }

  void _deactivate() {
    _breathController?.stop();
    final visibility = _visibilityController;
    if (visibility == null) {
      return;
    }
    visibility.duration = _fadeOut;
    unawaited(visibility.reverse());
  }

  @override
  void dispose() {
    _visibilityController?.dispose();
    _breathController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibility = _visibilityController;
    if (visibility == null && !widget.active) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listenable = Listenable.merge([
      visibility ?? const AlwaysStoppedAnimation<double>(0),
      ?_breathController,
    ]);

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: listenable,
          builder: (context, child) {
            final opacity = (visibility?.value ?? 0).clamp(0.0, 1.0);
            if (opacity <= 0) {
              return const SizedBox.shrink();
            }
            final breathT = _reduceMotion
                ? 0.5
                : AppMotion.curveBreath.transform(
                    _breathController?.value ?? 0.5,
                  );
            return Opacity(
              opacity: opacity,
              child: SizedBox(
                height: CreditLimitHorizonGlow.crestHeight,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DebtInwardWashPainter(
                    isDark: isDark,
                    breath: breathT,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Top-edge emitter: the upper half is clipped away so light only falls down.
class _DebtInwardWashPainter extends CustomPainter {
  const _DebtInwardWashPainter({
    required this.isDark,
    required this.breath,
  });

  final bool isDark;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    canvas
      ..save()
      ..clipRect(Offset.zero & size);

    final base = isDark ? AppColors.debt : AppColors.debtLight;
    final origin = Offset(size.width / 2, 8);
    final ambientAlpha = ui.lerpDouble(
      AppColors.alphaSoft,
      AppColors.alphaMedium,
      breath,
    )!;
    final coreAlpha = ui.lerpDouble(
      AppColors.alphaMedium,
      AppColors.alphaStrong,
      breath,
    )!;
    final ambientBlur = isDark ? 28.0 + (8.0 * breath) : 24.0 + (6.0 * breath);
    final coreBlur = isDark ? 14.0 + (4.0 * breath) : 12.0 + (3.0 * breath);

    final ambient = Paint()
      ..color = base.withValues(alpha: ambientAlpha)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, ambientBlur);
    canvas.drawOval(
      Rect.fromCenter(
        center: origin,
        width: size.width * 0.96,
        height: 80 + (16 * breath),
      ),
      ambient,
    );

    final core = Paint()
      ..color = base.withValues(alpha: coreAlpha)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, coreBlur);
    canvas.drawOval(
      Rect.fromCenter(
        center: origin,
        width: size.width * 0.48,
        height: 36 + (10 * breath),
      ),
      core,
    );

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          base.withValues(alpha: 0),
          base.withValues(alpha: AppColors.alphaMedium),
          base.withValues(alpha: 0),
        ],
        stops: const [0.08, 0.5, 0.92],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 3));
    canvas
      ..drawLine(const Offset(0, 1), Offset(size.width, 1), hairline)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _DebtInwardWashPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.breath != breath;
  }
}
