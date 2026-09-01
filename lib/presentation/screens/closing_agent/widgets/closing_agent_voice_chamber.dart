import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:flutter/material.dart';

/// Harmonic acoustic ribbon for hold-to-talk inside the glass composer dock.
class ClosingAgentVoiceChamber extends StatefulWidget {
  const ClosingAgentVoiceChamber({
    required this.cancelArmed,
    this.amplitudeStream,
    super.key,
  });

  final bool cancelArmed;
  final Stream<double>? amplitudeStream;

  /// Matches idle ink field height inside the dock.
  static const double chamberHeight = 40;

  /// Fixed footer strip — timer + cancel hint (prevents vertical creep).
  static const double statusStripHeight = 16;

  @override
  State<ClosingAgentVoiceChamber> createState() => _ClosingAgentVoiceChamberState();
}

class _ClosingAgentVoiceChamberState extends State<ClosingAgentVoiceChamber>
    with SingleTickerProviderStateMixin {
  AnimationController? _phaseController;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  double _liveAmplitude = 0.55;
  StreamSubscription<double>? _amplitudeSub;
  bool _motionReady = false;

  @override
  void initState() {
    super.initState();
    _bindAmplitude(widget.amplitudeStream);
    _startElapsedTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionReady) {
      _motionReady = true;
      _startMotion();
    }
  }

  @override
  void didUpdateWidget(ClosingAgentVoiceChamber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _bindAmplitude(widget.amplitudeStream);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _phaseController?.stop();
    } else if (_phaseController != null && !_phaseController!.isAnimating) {
      unawaited(_phaseController!.repeat());
    }
  }

  @override
  void dispose() {
    unawaited(_amplitudeSub?.cancel());
    _elapsedTimer?.cancel();
    _phaseController?.dispose();
    super.dispose();
  }

  void _startMotion() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return;
    }
    _phaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    unawaited(_phaseController!.repeat());
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsedSeconds = (_elapsedSeconds + 1).clamp(
          0,
          ClosingAgentConstants.maxVoiceCapture.inSeconds,
        );
      });
    });
  }

  void _bindAmplitude(Stream<double>? stream) {
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;
    if (stream == null) {
      return;
    }
    _amplitudeSub = stream.listen((sample) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveAmplitude = sample.clamp(0.0, 1.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final cancelInk = isDark ? AppColors.debt : AppColors.debtLight;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final phaseController = _phaseController;

    return Semantics(
      liveRegion: true,
      label: l10n.closingAgentMicRecordingElapsed(_elapsedSeconds),
      child: ClipRect(
        child: SizedBox(
          height: ClosingAgentVoiceChamber.chamberHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: reduceMotion || phaseController == null
                      ? _StaticRibbon(
                          isDark: isDark,
                          envelope: _liveAmplitude,
                        )
                      : AnimatedBuilder(
                          animation: phaseController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _HarmonicRibbonPainter(
                                phase: phaseController.value * math.pi * 2,
                                envelope: _proceduralEnvelope(
                                  phaseController.value,
                                  _liveAmplitude,
                                ),
                                isDark: isDark,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                ),
              ),
              SizedBox(
                height: ClosingAgentVoiceChamber.statusStripHeight,
                child: _ChamberStatusStrip(
                  elapsedSeconds: _elapsedSeconds,
                  cancelArmed: widget.cancelArmed,
                  inkSecondary: inkSecondary,
                  cancelInk: cancelInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _proceduralEnvelope(double phase01, double live) {
    final breath = 0.45 + 0.15 * math.sin(phase01 * math.pi * 2);
    if (widget.amplitudeStream == null) {
      return breath;
    }
    return (0.35 + 0.65 * live).clamp(0.35, 1.0);
  }
}

class _ChamberStatusStrip extends StatelessWidget {
  const _ChamberStatusStrip({
    required this.elapsedSeconds,
    required this.cancelArmed,
    required this.inkSecondary,
    required this.cancelInk,
  });

  final int elapsedSeconds;
  final bool cancelArmed;
  final Color inkSecondary;
  final Color cancelInk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Flexible(
          child: Text(
            '${l10n.closingAgentMicRecording} · ${_formatElapsed(elapsedSeconds)}',
            style: AppTextStyles.amountMicro.copyWith(color: inkSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingXs),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AnimatedSwitcher(
              duration: AppDimensions.animationFast,
              switchInCurve: AppMotion.curveEnter,
              switchOutCurve: AppMotion.curveExit,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: AlignmentDirectional.centerEnd,
                  children: [
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              child: Text(
                cancelArmed
                    ? l10n.closingAgentMicReleaseToCancel
                    : l10n.closingAgentMicSlideToCancel,
                key: ValueKey<bool>(cancelArmed),
                style: AppTextStyles.labelSmall.copyWith(
                  color: cancelArmed ? cancelInk : inkSecondary,
                  fontWeight:
                      cancelArmed ? FontWeight.w600 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatElapsed(int seconds) {
    final capped = seconds.clamp(
      0,
      ClosingAgentConstants.maxVoiceCapture.inSeconds,
    );
    final mm = (capped ~/ 60).toString().padLeft(1, '0');
    final ss = (capped % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _StaticRibbon extends StatelessWidget {
  const _StaticRibbon({
    required this.isDark,
    required this.envelope,
  });

  final bool isDark;
  final double envelope;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HarmonicRibbonPainter(
        phase: 0,
        envelope: envelope.clamp(0.45, 0.75),
        isDark: isDark,
        staticBars: true,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _HarmonicRibbonPainter extends CustomPainter {
  _HarmonicRibbonPainter({
    required this.phase,
    required this.envelope,
    required this.isDark,
    this.staticBars = false,
  });

  final double phase;
  final double envelope;
  final bool isDark;
  final bool staticBars;

  @override
  void paint(Canvas canvas, Size size) {
    if (staticBars) {
      _paintStaticBars(canvas, size);
      return;
    }

    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final waves = [
      (freq: 2.4, amp: 0.22, offset: 0.0, alpha: 0.28, width: 1.0),
      (freq: 3.1, amp: 0.16, offset: 1.2, alpha: 0.22, width: 1.25),
      (freq: 1.8, amp: 0.12, offset: 2.4, alpha: 0.18, width: 0.9),
    ];

    for (final wave in waves) {
      final path = Path();
      final midY = size.height * 0.5;
      final ampPx = size.height * wave.amp * envelope;
      for (var x = 0.0; x <= size.width; x += 2) {
        final t = x / size.width;
        final y = midY +
            math.sin((t * wave.freq * math.pi * 2) + phase + wave.offset) *
                ampPx;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final softPaint = Paint()
        ..color = lapis.withValues(alpha: wave.alpha * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = wave.width + 0.75
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, softPaint);

      final corePaint = Paint()
        ..color = lapis.withValues(alpha: wave.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = wave.width
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, corePaint);
    }
  }

  void _paintStaticBars(Canvas canvas, Size size) {
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    const barCount = 3;
    final gap = size.width / (barCount * 2);
    final midY = size.height * 0.5;
    final heights = [
      size.height * 0.18 * envelope,
      size.height * 0.28 * envelope,
      size.height * 0.2 * envelope,
    ];

    for (var i = 0; i < barCount; i++) {
      final x = gap + i * gap * 2;
      final h = heights[i];
      final paint = Paint()
        ..color = lapis.withValues(alpha: 0.24 + i * 0.04)
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonicRibbonPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.envelope != envelope ||
        oldDelegate.isDark != isDark ||
        oldDelegate.staticBars != staticBars;
  }
}
