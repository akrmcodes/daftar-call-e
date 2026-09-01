import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:daftar/presentation/shared/widgets/khazna_specular_panel.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Cinematic idle studio for the Closing Agent — vault hero + intent satellites.
class ClosingAgentIdleStudio extends StatelessWidget {
  const ClosingAgentIdleStudio({
    required this.isDark,
    required this.onExampleSelected,
    required this.onCloseToday,
    this.keyboardOpen = false,
    this.paddingBottom = 0,
    super.key,
  });

  final bool isDark;
  final ValueChanged<String> onExampleSelected;
  final VoidCallback onCloseToday;
  final bool keyboardOpen;
  final double paddingBottom;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final examples = <String>[
      l10n.closingAgentExampleChip1,
      l10n.closingAgentExampleChip2,
    ];
    final closeTodayLabel = l10n.closingAgentCloseToday;
    final closeTodaySemantics = l10n.closingAgentCloseTodaySemantics;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: _IdleLayout(
              inkPrimary: inkPrimary,
              inkSecondary: inkSecondary,
              title: l10n.closingAgentEmptyTitle,
              subtitle: l10n.closingAgentEmptySubtitle,
              examples: examples,
              hideSatellites: keyboardOpen,
              closeTodayLabel: closeTodayLabel,
              closeTodaySemantics: closeTodaySemantics,
              onExampleSelected: onExampleSelected,
              onCloseToday: onCloseToday,
            ),
          ),
        ),
        if (paddingBottom > 0)
          SliverToBoxAdapter(child: SizedBox(height: paddingBottom)),
      ],
    );
  }
}

class _IdleLayout extends StatelessWidget {
  const _IdleLayout({
    required this.inkPrimary,
    required this.inkSecondary,
    required this.title,
    required this.subtitle,
    required this.examples,
    required this.hideSatellites,
    required this.closeTodayLabel,
    required this.closeTodaySemantics,
    required this.onExampleSelected,
    required this.onCloseToday,
  });

  final Color inkPrimary;
  final Color inkSecondary;
  final String title;
  final String subtitle;
  final List<String> examples;
  final bool hideSatellites;
  final String closeTodayLabel;
  final String closeTodaySemantics;
  final ValueChanged<String> onExampleSelected;
  final VoidCallback onCloseToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ClosingAgentVaultSeal(),
        const Gap(AppDimensions.spacingXl),
        FadeSlideTransition(
          delay: const Duration(milliseconds: 30),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              color: inkPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        FadeSlideTransition(
          delay: const Duration(milliseconds: 60),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
          ),
        ),
        if (!hideSatellites) ...[
          const Gap(AppDimensions.spacingXl),
          FadeSlideTransition(
            delay: const Duration(milliseconds: 90),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppDimensions.spacingSm,
                  runSpacing: AppDimensions.spacingSm,
                  children: [
                    for (var i = 0; i < examples.length; i++)
                      _IntentSatellite(
                        label: examples[i],
                        delay: Duration(milliseconds: 90 + i * 30),
                        onTap: () => onExampleSelected(examples[i]),
                      ),
                  ],
                ),
                const Gap(AppDimensions.spacingSm),
                _CloseTodaySeal(
                  label: closeTodayLabel,
                  semanticsLabel: closeTodaySemantics,
                  onTap: onCloseToday,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CloseTodaySeal extends StatefulWidget {
  const _CloseTodaySeal({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  State<_CloseTodaySeal> createState() => _CloseTodaySealState();
}

class _CloseTodaySealState extends State<_CloseTodaySeal>
    with TickerProviderStateMixin {
  static const _entranceDelay = Duration(milliseconds: 400);
  static const _entranceDuration = Duration(milliseconds: 300);
  static const _catchPeriod = Duration(milliseconds: 2400);

  AnimationController? _entranceController;
  AnimationController? _catchController;
  bool _motionReady = false;
  bool _pressed = false;

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
  void dispose() {
    _entranceController?.dispose();
    _catchController?.dispose();
    super.dispose();
  }

  void _startMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    Future<void>.delayed(_entranceDelay, () {
      if (!mounted) {
        return;
      }
      _entranceController = AnimationController(
        vsync: this,
        duration: _entranceDuration,
      );
      _catchController = AnimationController(
        vsync: this,
        duration: _catchPeriod,
      );
      unawaited(_entranceController!.forward());
      unawaited(_catchController!.repeat());
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final lapisBorder = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final entranceController = _entranceController;
    final catchController = _catchController;

    // Elongated squircle — stadium (radiusCircular) clipped the crescent
    // against the pill caps and starved the hairline at the corners.
    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusLg,
      cornerSmoothing: 0.8,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        ?entranceController,
        ?catchController,
      ]),
      builder: (context, _) {
        final entrance = reduceMotion
            ? 1.0
            : entranceController == null
            ? 0.0
            : AppMotion.curveEnter.transform(entranceController.value);
        final catchPhase =
            reduceMotion || catchController == null ? 0.0 : catchController.value;

        return Opacity(
          opacity: entrance.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.96 + 0.04 * entrance,
            child: Semantics(
              button: true,
              label: widget.semanticsLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: () {
                  unawaited(HapticService.selection());
                  widget.onTap();
                },
                child: DaftarTapTarget(
                  child: AnimatedScale(
                    scale: _pressed ? 0.97 : 1,
                    duration: AppDimensions.animationFast,
                    curve: AppMotion.curveEnter,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: SmoothRectangleBorder(
                          borderRadius: squircleRadius,
                        ),
                        shadows:
                            isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
                      ),
                      child: Stack(
                        children: [
                          ClipSmoothRect(
                            radius: squircleRadius,
                            child: KhaznaSpecularPanel(
                              padding:
                                  const EdgeInsetsDirectional.fromSTEB(
                                AppDimensions.spacingXxl,
                                AppDimensions.spacingSm + 4,
                                AppDimensions.spacingXxl,
                                AppDimensions.spacingSm + 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CrescentGlyph(color: inkMuted),
                                  const Gap(AppDimensions.spacingXs),
                                  Text(
                                    widget.label,
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: ink,
                                      letterSpacing: 0.6,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _SealHairlineCatchPainter(
                                  borderRadius: squircleRadius,
                                  lapis: lapisBorder,
                                  phase: catchPhase,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Filled crescent moon — inset so the glyph never clips.
class _CrescentGlyph extends StatelessWidget {
  const _CrescentGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        key: const ValueKey<String>('close-today-crescent'),
        painter: _CrescentGlyphPainter(color: color),
      ),
    );
  }
}

class _CrescentGlyphPainter extends CustomPainter {
  const _CrescentGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 1.5;
    final radius = size.shortestSide / 2 - inset;
    final outerCenter = Offset(size.width * 0.46, size.height / 2);
    final innerCenter = Offset(size.width * 0.64, size.height * 0.40);
    final outer = Path()
      ..addOval(Rect.fromCircle(center: outerCenter, radius: radius));
    final inner = Path()
      ..addOval(Rect.fromCircle(center: innerCenter, radius: radius * 0.78));
    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(
      crescent,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _CrescentGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SealHairlineCatchPainter extends CustomPainter {
  const _SealHairlineCatchPainter({
    required this.borderRadius,
    required this.lapis,
    required this.phase,
  });

  final SmoothBorderRadius borderRadius;
  final Color lapis;
  final double phase;

  static const double _inset = 1;
  static const double _stroke = 1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= _inset * 2 || size.height <= _inset * 2) {
      return;
    }
    final rect = Rect.fromLTWH(
      _inset,
      _inset,
      size.width - _inset * 2,
      size.height - _inset * 2,
    );
    final insetRadius = SmoothBorderRadius(
      cornerRadius: math.max(0, AppDimensions.radiusLg - _inset),
      cornerSmoothing: 0.8,
    );
    final path = SmoothRectangleBorder(
      borderRadius: insetRadius,
    ).getOuterPath(rect);

    final hairline = Paint()
      ..color = lapis.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(path, hairline);

    if (phase <= 0) {
      return;
    }

    final highlight = Paint()
      ..color = lapis.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke + 0.35
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (final metric in path.computeMetrics()) {
      final total = metric.length;
      if (total <= 0) {
        continue;
      }
      final gleamLength = math.max<double>(36, total * 0.22);
      _drawWrappedSegment(
        canvas,
        metric,
        phase * total,
        gleamLength,
        highlight,
      );
    }
  }

  void _drawWrappedSegment(
    Canvas canvas,
    PathMetric metric,
    double center,
    double length,
    Paint paint,
  ) {
    final total = metric.length;
    final half = math.min(length / 2, total / 2);
    final start = _wrap(center - half, total);
    final end = _wrap(center + half, total);
    if (start <= end) {
      canvas.drawPath(metric.extractPath(start, end), paint);
      return;
    }
    canvas
      ..drawPath(metric.extractPath(start, total), paint)
      ..drawPath(metric.extractPath(0, end), paint);
  }

  double _wrap(double value, double modulus) {
    final wrapped = value % modulus;
    return wrapped < 0 ? wrapped + modulus : wrapped;
  }

  @override
  bool shouldRepaint(covariant _SealHairlineCatchPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.lapis != lapis;
  }
}

class _IntentSatellite extends StatelessWidget {
  const _IntentSatellite({
    required this.label,
    required this.onTap,
    this.delay = Duration.zero,
  });

  final String label;
  final VoidCallback onTap;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return FadeSlideTransition(
      delay: delay,
      child: KhaznaSpecularPanel(
        shape: KhaznaSpecularPanelShape.pill,
        onTap: onTap,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelMedium.copyWith(color: ink),
        ),
      ),
    );
  }
}
