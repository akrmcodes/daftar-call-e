import 'dart:math' as math;
import 'dart:ui' as ui show PathMetric, TextDirection;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/presentation/providers/architecture_hud_provider.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact contest Architecture HUD — Khazna flight instrument.
///
/// Presentation-only. Data comes from [architectureHudSnapshotProvider]
/// (`AgentTurnResult` echo + HITL rail + send-batch Message-ID).
/// Never Cloud Logging. No [BackdropFilter] — fake glass only.
class DaftarArchitectureHud extends ConsumerWidget {
  /// Creates the HUD overlay.
  const DaftarArchitectureHud({super.key});

  /// Key on the visible instrument (absent when the overlay is hidden).
  static const overlayKey = ValueKey<String>('daftarArchitectureHudOverlay');

  static const double _maxWidth = 296;

  static const TextStyle _resetTextStyle = TextStyle(
    inherit: false,
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
    decorationThickness: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(architectureHudSnapshotProvider);
    if (!snapshot.visible) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final model = snapshot.modelId?.trim() ?? '';
    final emailTail = ArchitectureHudSnapshot.tail8(snapshot.smtpMessageId);
    final callTail = ArchitectureHudSnapshot.tail8(snapshot.callRunId);
    final callStatus = snapshot.callStatus;

    final clampedScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 1,
      maxScaleFactor: 1.15,
    );

    return PositionedDirectional(
      key: overlayKey,
      top: 0,
      end: 0,
      child: IgnorePointer(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.spacingSm,
              AppDimensions.spacingXs,
              AppDimensions.spacingSm,
              0,
            ),
            child: Semantics(
              container: true,
              label: l10n.architectureHudSemantics(
                _hitlStepLabel(l10n, snapshot.hitlStep),
              ),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: clampedScaler,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: SelectionContainer.disabled(
                    child: DefaultTextStyle(
                      style: _resetTextStyle,
                      child: ExcludeSemantics(
                        child: _ArchitectureHudChrome(
                          isDark: isDark,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppDimensions.spacingSm,
                              AppDimensions.spacingSm,
                              AppDimensions.spacingSm,
                              AppDimensions.spacingSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RoutingHeader(
                                  l10n: l10n,
                                  snapshot: snapshot,
                                  model: model,
                                  isDark: isDark,
                                  inkPrimary: inkPrimary,
                                ),
                                if (_scopeBand(l10n, snapshot) != null) ...[
                                  const SizedBox(height: AppDimensions.spacingXs),
                                  _scopeBand(l10n, snapshot)!,
                                ],
                                const SizedBox(height: AppDimensions.spacingSm),
                                _HitlTraceRail(
                                  current: snapshot.hitlStep,
                                  inkPrimary: inkPrimary,
                                  inkSecondary: inkSecondary,
                                  inkMuted: inkMuted,
                                  isDark: isDark,
                                  reduceMotion: reduceMotion,
                                  l10n: l10n,
                                ),
                                if (_proposalLine(l10n, snapshot, inkMuted) !=
                                    null) ...[
                                  const SizedBox(height: AppDimensions.spacingXs),
                                  _proposalLine(l10n, snapshot, inkMuted)!,
                                ],
                                if (callStatus != null) ...[
                                  const SizedBox(height: AppDimensions.spacingXxs),
                                  _CallChipRow(
                                    l10n: l10n,
                                    runIdTail: callTail,
                                    status: callStatus,
                                    ink: inkSecondary,
                                    isDark: isDark,
                                    reduceMotion: reduceMotion,
                                  ),
                                ],
                                if (emailTail != null) ...[
                                  const SizedBox(height: AppDimensions.spacingXxs),
                                  _EmailSentRow(
                                    label: l10n.architectureHudEmailSent(emailTail),
                                    ink: inkSecondary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _hitlStepLabel(
    AppLocalizations l10n,
    ArchitectureHudHitlStep step,
  ) {
    return switch (step) {
      ArchitectureHudHitlStep.propose => l10n.architectureHudHitlPropose,
      ArchitectureHudHitlStep.confirm => l10n.architectureHudHitlConfirm,
      ArchitectureHudHitlStep.commit => l10n.architectureHudHitlCommit,
      ArchitectureHudHitlStep.rank => l10n.architectureHudHitlRank,
    };
  }

  static Widget? _proposalLine(
    AppLocalizations l10n,
    ArchitectureHudSnapshot snapshot,
    Color ink,
  ) {
    if (snapshot.pendingCount == 0 &&
        snapshot.committedCount == 0 &&
        snapshot.skippedCount == 0) {
      return null;
    }
    final parts = <String>[
      l10n.architectureHudPendingRecorded(
        snapshot.pendingCount,
        snapshot.committedCount,
      ),
    ];
    if (snapshot.skippedCount > 0) {
      parts.add(l10n.architectureHudSkipped(snapshot.skippedCount));
    }
    return _HudText(
      data: parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _HudType.latinMicro(ink),
    );
  }

  static Widget? _scopeBand(
    AppLocalizations l10n,
    ArchitectureHudSnapshot snapshot,
  ) {
    final scopeLabel = switch (snapshot.toolScope) {
      ArchitectureHudToolScope.capture => l10n.architectureHudScopeCapture,
      ArchitectureHudToolScope.close => l10n.architectureHudScopeClose,
      ArchitectureHudToolScope.ask => l10n.architectureHudScopeAsk,
      ArchitectureHudToolScope.none => null,
    };
    final tools = snapshot.toolNames.join(' · ');
    if (scopeLabel == null && tools.isEmpty) {
      return null;
    }
    return _ScopeBand(
      scopeLabel: scopeLabel,
      tools: tools,
      l10n: l10n,
    );
  }
}

/// Instrument typography — Inter for Latin/IDs, stripped Noto for Arabic words.
abstract final class _HudType {
  static TextStyle latinRouting(Color color, {FontWeight? weight}) {
    return AppTextStyles.numeralCaption.copyWith(
      color: color,
      fontSize: 11,
      height: 1.2,
      letterSpacing: 0.15,
      fontWeight: weight ?? FontWeight.w500,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
    );
  }

  static TextStyle latinMicro(Color color, {FontWeight? weight}) {
    return AppTextStyles.numeralCaption.copyWith(
      color: color,
      fontSize: 10,
      height: 1.2,
      letterSpacing: 0,
      fontWeight: weight ?? FontWeight.w500,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
    );
  }

  static TextStyle arabicWord(Color color, {FontWeight? weight}) {
    return AppTextStyles.labelSmall.copyWith(
      fontFamily: AppTextStyles.arabicFontFamily,
      color: color,
      fontSize: 10,
      height: 1.25,
      letterSpacing: 0,
      fontWeight: weight ?? FontWeight.w500,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
      decorationThickness: 0,
    );
  }

  static TextStyle forLocale(
    BuildContext context,
    Color color, {
    FontWeight? weight,
  }) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    if (isArabic) {
      return arabicWord(color, weight: weight);
    }
    return latinMicro(color, weight: weight);
  }
}

class _HudText extends StatelessWidget {
  const _HudText({
    required this.data,
    required this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.textDirection,
  });

  final String data;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;

  static const TextHeightBehavior _heightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      textDirection: textDirection,
      textHeightBehavior: _heightBehavior,
      style: style,
    );
  }
}

class _ArchitectureHudChrome extends StatelessWidget {
  const _ArchitectureHudChrome({
    required this.isDark,
    required this.child,
  });

  final bool isDark;
  final Widget child;

  static final _squircleRadius = SmoothBorderRadius(
    cornerRadius: AppDimensions.radiusSm,
    cornerSmoothing: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark ? AppColors.glassBorder : AppColors.glassBorderLight;
    final specularRazor =
        isDark ? AppColors.specularRazorDark : AppColors.specularRazorLight;
    final fresnelSheen = isDark
        ? const Color(0x05FFFFFF)
        : const Color(0x04FFFFFF);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(borderRadius: _squircleRadius),
        shadows: [
          ...AppGlows.haloXs,
          ...(isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat),
        ],
      ),
      child: ClipSmoothRect(
        radius: _squircleRadius,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: glassFill)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fresnelSheen, Colors.transparent],
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
                painter: _HudSpecularRimPainter(
                  borderRadius: _squircleRadius,
                  isDark: isDark,
                  glassBorder: glassBorder,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _HudSpecularRimPainter extends CustomPainter {
  const _HudSpecularRimPainter({
    required this.borderRadius,
    required this.isDark,
    required this.glassBorder,
  });

  final SmoothBorderRadius borderRadius;
  final bool isDark;
  final Color glassBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = SmoothRectangleBorder(borderRadius: borderRadius);
    final path = shape.getOuterPath(rect);
    const lightDirection = Offset(0, -1);

    for (final metric in path.computeMetrics()) {
      _paintSegmentRim(canvas, metric, lightDirection);
    }
  }

  void _paintSegmentRim(
    Canvas canvas,
    ui.PathMetric metric,
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
      final facing =
          normal.dx * lightDirection.dx + normal.dy * lightDirection.dy;
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
      canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HudSpecularRimPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.glassBorder != glassBorder;
  }
}

class _RoutingHeader extends StatelessWidget {
  const _RoutingHeader({
    required this.l10n,
    required this.snapshot,
    required this.model,
    required this.isDark,
    required this.inkPrimary,
  });

  final AppLocalizations l10n;
  final ArchitectureHudSnapshot snapshot;
  final String model;
  final bool isDark;
  final Color inkPrimary;

  @override
  Widget build(BuildContext context) {
    final routing = model.isNotEmpty ? l10n.architectureHudRouting(model) : '';
    final chips = <Widget>[];
    if (snapshot.isRunning) {
      chips.add(
        _MetaChip(
          label: l10n.architectureHudLatencyPending,
          isDark: isDark,
          accent: true,
        ),
      );
    } else {
      final latencyMs = snapshot.latencyMs;
      if (latencyMs != null) {
        chips.add(
          _MetaChip(
            label: l10n.architectureHudLatency(latencyMs),
            isDark: isDark,
          ),
        );
      }
    }
    final correlationTail =
        ArchitectureHudSnapshot.tail8(snapshot.correlationId);
    if (correlationTail != null) {
      chips.add(
        _MetaChip(
          label: l10n.architectureHudCorrelation(correlationTail),
          isDark: isDark,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusOrb(isRunning: snapshot.isRunning, isDark: isDark),
        const SizedBox(width: AppDimensions.spacingXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (routing.isNotEmpty)
                _HudText(
                  data: routing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _HudType.latinRouting(inkPrimary),
                ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingXxs),
                Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0)
                        const SizedBox(width: AppDimensions.spacingXxs),
                      Flexible(child: chips[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusOrb extends StatelessWidget {
  const _StatusOrb({required this.isRunning, required this.isDark});

  final bool isRunning;
  final bool isDark;

  static const double _size = 6;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingXxs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(
            color: isRunning
                ? AppColors.lapis400
                : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight),
            width: isRunning ? 1.5 : 0.5,
          ),
          boxShadow: isRunning ? AppGlows.haloXs : null,
        ),
        child: const SizedBox(width: _size, height: _size),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.isDark,
    this.accent = false,
  });

  final String label;
  final bool isDark;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final border = isDark ? AppColors.glassBorder : AppColors.glassBorderLight;
    final ink = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(
          color: accent ? AppColors.lapis400 : border,
          width: accent ? 0.5 : AppDimensions.dividerThickness,
        ),
        boxShadow: accent ? AppGlows.haloXs : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXs,
          vertical: AppDimensions.spacingXxs,
        ),
        child: _HudText(
          data: label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _HudType.latinMicro(ink),
        ),
      ),
    );
  }
}

class _ScopeBand extends StatelessWidget {
  const _ScopeBand({
    required this.scopeLabel,
    required this.tools,
    required this.l10n,
  });

  final String? scopeLabel;
  final String tools;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final hasScope = scopeLabel != null;

    return Row(
      children: [
        if (hasScope) ...[
          _ScopePill(label: scopeLabel!, isDark: isDark),
          if (tools.isNotEmpty) const SizedBox(width: AppDimensions.spacingXs),
        ],
        if (tools.isNotEmpty)
          Expanded(
            child: _HudText(
              data: hasScope ? tools : l10n.architectureHudTool(tools),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _HudType.latinMicro(inkMuted),
            ),
          ),
      ],
    );
  }
}

class _ScopePill extends StatelessWidget {
  const _ScopePill({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final ink = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(
          color: AppColors.lapis400,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXs,
          vertical: AppDimensions.spacingXxs,
        ),
        child: _HudText(
          data: label,
          style: _HudType.forLocale(
            context,
            ink,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HitlTraceRail extends StatelessWidget {
  const _HitlTraceRail({
    required this.current,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.isDark,
    required this.reduceMotion,
    required this.l10n,
  });

  final ArchitectureHudHitlStep current;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;
  final bool isDark;
  final bool reduceMotion;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    const steps = ArchitectureHudHitlStep.values;
    final currentIndex = steps.indexOf(current);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: CustomPaint(
            painter: _HitlTracePainter(
              stepCount: steps.length,
              currentIndex: currentIndex,
              isDark: isDark,
            ),
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: Center(
                      child: _TraceNode(
                        state: _nodeState(i, currentIndex),
                        reduceMotion: reduceMotion,
                        isDark: isDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: _HudText(
                  data: _labelFor(steps[i]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _HudType.forLocale(
                    context,
                    _labelInk(i, currentIndex),
                    weight: i == currentIndex
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _labelInk(int index, int currentIndex) {
    if (index == currentIndex) {
      return inkPrimary;
    }
    if (index < currentIndex) {
      return inkSecondary;
    }
    return inkMuted;
  }

  _TraceNodeState _nodeState(int index, int currentIndex) {
    if (index == currentIndex) {
      return _TraceNodeState.current;
    }
    if (index < currentIndex) {
      return _TraceNodeState.completed;
    }
    return _TraceNodeState.future;
  }

  String _labelFor(ArchitectureHudHitlStep step) {
    return switch (step) {
      ArchitectureHudHitlStep.propose => l10n.architectureHudHitlPropose,
      ArchitectureHudHitlStep.confirm => l10n.architectureHudHitlConfirm,
      ArchitectureHudHitlStep.commit => l10n.architectureHudHitlCommit,
      ArchitectureHudHitlStep.rank => l10n.architectureHudHitlRank,
    };
  }
}

enum _TraceNodeState { completed, current, future }

class _TraceNode extends StatelessWidget {
  const _TraceNode({
    required this.state,
    required this.reduceMotion,
    required this.isDark,
  });

  final _TraceNodeState state;
  final bool reduceMotion;
  final bool isDark;

  static const double _size = 8;

  @override
  Widget build(BuildContext context) {
    final isCompleted = state == _TraceNodeState.completed;
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final mutedRing = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;

    Color ringColor;
    double ringWidth;
    List<BoxShadow>? glow;

    switch (state) {
      case _TraceNodeState.current:
        ringColor = AppColors.lapis400;
        ringWidth = 1.5;
        glow = reduceMotion ? null : AppGlows.haloXs;
      case _TraceNodeState.completed:
        ringColor = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
        ringWidth = 1;
        glow = null;
      case _TraceNodeState.future:
        ringColor = mutedRing;
        ringWidth = 0.5;
        glow = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? ringColor.withValues(alpha: AppColors.alphaSoft) : fill,
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: glow,
      ),
      child: const SizedBox(width: _size, height: _size),
    );
  }
}

class _HitlTracePainter extends CustomPainter {
  const _HitlTracePainter({
    required this.stepCount,
    required this.currentIndex,
    required this.isDark,
  });

  final int stepCount;
  final int currentIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (stepCount < 2) {
      return;
    }
    final paint = Paint()
      ..color = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight
      ..strokeWidth = AppDimensions.dividerThickness
      ..style = PaintingStyle.stroke;

    final segment = size.width / stepCount;
    final y = size.height / 2;
    final startX = segment / 2;
    final endX = size.width - segment / 2;

    canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);

    if (currentIndex > 0) {
      final progressPaint = Paint()
        ..color = AppColors.lapis400.withValues(alpha: AppColors.alphaMedium)
        ..strokeWidth = AppDimensions.dividerThickness
        ..style = PaintingStyle.stroke;
      final progressEnd = startX + segment * currentIndex;
      canvas.drawLine(Offset(startX, y), Offset(progressEnd, y), progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HitlTracePainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex ||
        oldDelegate.stepCount != stepCount ||
        oldDelegate.isDark != isDark;
  }
}

class _CallChipRow extends StatelessWidget {
  const _CallChipRow({
    required this.l10n,
    required this.runIdTail,
    required this.status,
    required this.ink,
    required this.isDark,
    required this.reduceMotion,
  });

  final AppLocalizations l10n;
  final String? runIdTail;
  final CollectionsCallRowStatus status;
  final Color ink;
  final bool isDark;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(l10n, status);
    final iconColor = status == CollectionsCallRowStatus.failed
        ? (isDark ? AppColors.debt : AppColors.debtLight)
        : ink.withValues(alpha: AppColors.alphaStrong);

    final Widget labelWidget;
    if (runIdTail != null) {
      labelWidget = _HudText(
        data: l10n.architectureHudCallId(runIdTail!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _HudType.latinMicro(ink),
        textDirection: ui.TextDirection.ltr,
      );
    } else {
      labelWidget = _HudText(
        data: l10n.architectureHudCallStatusOnly(statusLabel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _HudType.latinMicro(ink),
      );
    }

    return Row(
      children: [
        Icon(
          Icons.call_made_rounded,
          size: 12,
          color: iconColor,
        ),
        const SizedBox(width: AppDimensions.spacingXxs),
        Expanded(child: labelWidget),
        if (runIdTail != null) ...[
          const SizedBox(width: AppDimensions.spacingXxs),
          _CallStatusPill(
            label: statusLabel,
            status: status,
            isDark: isDark,
            reduceMotion: reduceMotion,
          ),
        ],
      ],
    );
  }

  static String _statusLabel(
    AppLocalizations l10n,
    CollectionsCallRowStatus status,
  ) {
    return switch (status) {
      CollectionsCallRowStatus.planned => l10n.architectureHudCallPlanned,
      CollectionsCallRowStatus.ringing => l10n.architectureHudCallRinging,
      CollectionsCallRowStatus.completed => l10n.architectureHudCallCompleted,
      CollectionsCallRowStatus.failed => l10n.architectureHudCallFailed,
    };
  }
}

class _CallStatusPill extends StatelessWidget {
  const _CallStatusPill({
    required this.label,
    required this.status,
    required this.isDark,
    required this.reduceMotion,
  });

  final String label;
  final CollectionsCallRowStatus status;
  final bool isDark;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final mutedBorder =
        isDark ? AppColors.glassBorder : AppColors.glassBorderLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    Color borderColor;
    double borderWidth;
    List<BoxShadow>? glow;
    Color textColor;

    switch (status) {
      case CollectionsCallRowStatus.planned:
        borderColor = mutedBorder;
        borderWidth = 0.5;
        glow = null;
        textColor = inkMuted;
      case CollectionsCallRowStatus.ringing:
        borderColor = AppColors.lapis400;
        borderWidth = 0.5;
        glow = reduceMotion ? null : AppGlows.haloXs;
        textColor = inkSecondary;
      case CollectionsCallRowStatus.completed:
        borderColor = mutedBorder;
        borderWidth = AppDimensions.dividerThickness;
        glow = null;
        textColor = inkSecondary;
      case CollectionsCallRowStatus.failed:
        borderColor = isDark ? AppColors.debt : AppColors.debtLight;
        borderWidth = 0.5;
        glow = null;
        textColor = isDark ? AppColors.debt : AppColors.debtLight;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: glow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingXxs,
          vertical: 2,
        ),
        child: _HudText(
          data: label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _HudType.latinMicro(textColor, weight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmailSentRow extends StatelessWidget {
  const _EmailSentRow({required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.outbound_rounded,
          size: 12,
          color: ink.withValues(alpha: AppColors.alphaStrong),
        ),
        const SizedBox(width: AppDimensions.spacingXxs),
        Expanded(
          child: _HudText(
            data: label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _HudType.latinMicro(ink),
          ),
        ),
      ],
    );
  }
}
