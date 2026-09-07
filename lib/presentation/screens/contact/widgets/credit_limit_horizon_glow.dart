import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Top-of-sheet debt-red horizon for the credit-limit HITL sheet.
///
/// Same grammar as Closing Agent working glow: BoxShadow emission + hairline
/// stroke only — never a red fill on the sheet surface.
class CreditLimitHorizonGlow extends StatefulWidget {
  const CreditLimitHorizonGlow({
    required this.active,
    super.key,
  });

  /// When true the crest fades in and breathes; when false it exhales out.
  final bool active;

  static const double crestHeight = 200;

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
                child: _DebtHorizonCrest(
                  isDark: isDark,
                  breath: breathT,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DebtHorizonCrest extends StatelessWidget {
  const _DebtHorizonCrest({
    required this.isDark,
    required this.breath,
  });

  final bool isDark;
  final double breath;

  @override
  Widget build(BuildContext context) {
    final ambient = _ambientShadows(isDark, breath);
    final core = _coreShadows(isDark, breath);
    final coreScale = 0.94 + (0.12 * breath);
    final hairline = isDark ? AppColors.debt : AppColors.debtLight;
    final hairlinePeak = hairline.withValues(
      alpha: AppColors.alphaMedium + (AppColors.alphaSoft * breath),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            PositionedDirectional(
              top: -28,
              start: -width * 0.08,
              end: -width * 0.08,
              height: 56,
              child: _EmissiveBand(shadows: ambient),
            ),
            PositionedDirectional(
              top: -14,
              start: width * 0.22,
              end: width * 0.22,
              height: 28,
              child: Transform.scale(
                scale: coreScale,
                alignment: AlignmentDirectional.topCenter,
                child: _EmissiveBand(shadows: core),
              ),
            ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              height: 3,
              child: CustomPaint(
                painter: _DebtHairlinePainter(
                  color: hairline,
                  peak: hairlinePeak,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static List<BoxShadow> _ambientShadows(bool isDark, double breath) {
    final base = isDark ? AppColors.debt : AppColors.debtLight;
    final soft = base.withValues(alpha: AppColors.alphaSoft);
    final medium = base.withValues(alpha: AppColors.alphaMedium);
    return [
      BoxShadow.lerp(
        BoxShadow(color: soft, blurRadius: 64),
        BoxShadow(color: medium, blurRadius: 96, spreadRadius: 8),
        breath,
      )!,
    ];
  }

  static List<BoxShadow> _coreShadows(bool isDark, double breath) {
    final base = isDark ? AppColors.debt : AppColors.debtLight;
    final soft = base.withValues(alpha: AppColors.alphaSoft);
    final medium = base.withValues(alpha: AppColors.alphaMedium);
    return [
      BoxShadow.lerp(
        BoxShadow(color: soft, blurRadius: 8),
        BoxShadow(color: medium, blurRadius: 24),
        breath,
      )!,
    ];
  }
}

class _EmissiveBand extends StatelessWidget {
  const _EmissiveBand({required this.shadows});

  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.transparent,
        boxShadow: shadows,
      ),
    );
  }
}

class _DebtHairlinePainter extends CustomPainter {
  const _DebtHairlinePainter({
    required this.color,
    required this.peak,
  });

  final Color color;
  final Color peak;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) {
      return;
    }
    const y = 0.5;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          peak,
          color.withValues(alpha: 0),
        ],
        stops: const [0.06, 0.5, 0.94],
      ).createShader(rect);
    canvas.drawLine(const Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _DebtHairlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.peak != peak;
  }
}
