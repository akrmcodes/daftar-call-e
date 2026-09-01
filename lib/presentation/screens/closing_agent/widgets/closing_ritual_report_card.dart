import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/closing_report_speakable.dart';
import 'package:daftar/core/utils/closing_report_speech.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/core/utils/speech_script_locale.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_seal.dart';
import 'package:daftar/presentation/shared/widgets/daftar_brand_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_permission_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Hero close-the-day report with staged ceremonial reveal.
class ClosingRitualReportCard extends StatefulWidget {
  /// Creates the report card.
  const ClosingRitualReportCard({
    required this.result,
    this.ttsMuted = false,
    this.ttsLocale = 'ar',
    this.onSignInToDrive,
    this.onGrantDrive,
    super.key,
  });

  /// Ritual snapshot after prompts.
  final ClosingRitualResult result;

  /// When true, skip on-device TTS.
  final bool ttsMuted;

  /// Settings locale (`ar` / `en`) for TTS.
  final String ttsLocale;

  /// Sign in when tonight's Drive backup was skipped because the merchant
  /// is not signed in. Secondary CTA — no extra lapis glow.
  final VoidCallback? onSignInToDrive;

  /// Complete Drive offline grant when signed in but scopes were not approved.
  final VoidCallback? onGrantDrive;

  @override
  State<ClosingRitualReportCard> createState() =>
      _ClosingRitualReportCardState();
}

class _ClosingRitualReportCardState extends State<ClosingRitualReportCard>
    with TickerProviderStateMixin {
  static const double _heroSize = 88;
  static const double _markSize = 52;

  late final AnimationController _drawController;
  late final AnimationController _checkController;
  late final AnimationController _markController;
  late final AnimationController _catchController;
  Timer? _announceTimer;
  var _announced = false;
  var _markHandoffStarted = false;

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      SchedulerBinding.instance.platformDispatcher.accessibilityFeatures
          .disableAnimations;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationXSlow,
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _markController = AnimationController(
      vsync: this,
      duration: AppDimensions.animationMedium,
    );
    _catchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCeremony());
  }

  Future<void> _startCeremony() async {
    if (!mounted) {
      return;
    }
    if (_reduceMotion) {
      _drawController.value = 1;
      _checkController.value = 0;
      _markController.value = 1;
      _catchController.value = 1;
      _announceOnce();
      return;
    }
    await _drawController.forward();
    if (!mounted) {
      return;
    }
    await _checkController.forward();
    if (!mounted) {
      return;
    }
    unawaited(HapticService.selection());
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) {
      return;
    }
    _checkController.addListener(_maybeStartMarkHandoff);
    final reverseFuture = _checkController.reverse();
    await reverseFuture;
    _checkController.removeListener(_maybeStartMarkHandoff);
    if (!mounted) {
      return;
    }
    if (_markController.value < 1) {
      await _markController.forward();
    }
    if (!mounted) {
      return;
    }
    unawaited(HapticService.tierUpgrade());
    _announceTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      _announceOnce();
      unawaited(_catchController.forward());
    });
  }

  void _maybeStartMarkHandoff() {
    if (_markHandoffStarted || _checkController.status != AnimationStatus.reverse) {
      return;
    }
    if (_checkController.value <= 0.2) {
      _markHandoffStarted = true;
      unawaited(_markController.forward());
    }
  }

  void _announceOnce() {
    if (_announced) {
      return;
    }
    _announced = true;
    final l10n = lookupAppLocalizations(
      Locale(normalizeSpeechLocale(widget.ttsLocale)),
    );
    unawaited(
      ClosingReportSpeech.announce(
        closingReportSpeakable(l10n: l10n, result: widget.result),
        muted: widget.ttsMuted,
        locale: widget.ttsLocale,
      ),
    );
    if (widget.result.backupStatus != ClosingBackupStatus.uploaded) {
      unawaited(HapticService.transactionSaved());
    }
  }

  @override
  void dispose() {
    _announceTimer?.cancel();
    _drawController.dispose();
    _checkController.dispose();
    _markController.dispose();
    _catchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final payment = isDark ? AppColors.payment : AppColors.paymentLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final result = widget.result;
    final summary = result.summary;
    final reduceMotion = _reduceMotion;

    Widget stage(Widget child, {Duration delay = Duration.zero}) {
      if (reduceMotion) {
        return child;
      }
      return child
          .animate(delay: delay)
          .fadeIn(
            duration: AppDimensions.animationMedium,
            curve: AppMotion.curveEnter,
          )
          .slideY(
            begin: 0.04,
            end: 0,
            duration: AppDimensions.animationMedium,
            curve: AppMotion.curveEnter,
          );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _catchController,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _catchController.value > 0
                ? _HeroCatchPainter(
                    isDark: isDark,
                    progress: _catchController.value,
                  )
                : null,
            child: child,
          );
        },
        child: DaftarCard(
          variant: DaftarCardVariant.hero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: _heroSize,
                  height: _heroSize,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _drawController,
                      _checkController,
                      _markController,
                      _catchController,
                    ]),
                    builder: (context, _) {
                      final peakGlow =
                          widget.result.backupStatus ==
                              ClosingBackupStatus.uploaded
                          ? AppGlows.glowXl
                          : AppGlows.glowMd;
                      final t = _catchController.value.clamp(0.0, 1.0);
                      final drawProgress = AppMotion.curveEnter.transform(
                        _drawController.value,
                      );
                      final checkProgress = _checkController.value;
                      final markT = AppMotion.curveEnter.transform(
                        _markController.value,
                      );
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: t <= 0
                              ? null
                              : [
                                  BoxShadow(
                                    color: Color.lerp(
                                      peakGlow.color.withAlpha(0),
                                      peakGlow.color,
                                      t,
                                    )!,
                                    blurRadius: peakGlow.blurRadius * t,
                                  ),
                                ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(_heroSize, _heroSize),
                              painter: ClosingAgentVaultRingPainter(
                                isDark: isDark,
                                drawProgress: drawProgress,
                                highlightPhase: 0,
                              ),
                            ),
                            if (checkProgress > 0)
                              CustomPaint(
                                size: const Size(_heroSize, _heroSize),
                                painter: _VerifiedSealCheckPainter(
                                  isDark: isDark,
                                  progress: checkProgress,
                                ),
                              ),
                            Opacity(
                              opacity: markT.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.92 + 0.08 * markT,
                                child: const DaftarBrandMark(size: _markSize),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Gap(AppDimensions.spacingMd),
              stage(
                Text(
                  l10n.closingRitualReportTitle,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: inkPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                delay: const Duration(milliseconds: 200),
              ),
              const Gap(AppDimensions.spacingSm),
              stage(
                Text(
                  summary.localDay,
                  style: AppTextStyles.titleSmall.copyWith(color: inkSecondary),
                  textAlign: TextAlign.center,
                ),
                delay: const Duration(milliseconds: 280),
              ),
              const Gap(AppDimensions.spacingMd),
              stage(
                _CountRow(
                  unit: l10n.closingRitualReportDebtsUnit,
                  count: summary.debtCount,
                  inkPrimary: inkPrimary,
                  reduceMotion: reduceMotion,
                ),
                delay: const Duration(milliseconds: 360),
              ),
              stage(
                _CountRow(
                  unit: l10n.closingRitualReportPaymentsUnit,
                  count: summary.paymentCount,
                  inkPrimary: inkPrimary,
                  reduceMotion: reduceMotion,
                ),
                delay: const Duration(milliseconds: 440),
              ),
              if (summary.totals.isNotEmpty) ...[
                const Gap(AppDimensions.spacingSm),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: summary.totals.length,
                  itemBuilder: (context, index) {
                    final row = summary.totals[index];
                    final debt = MoneyUtil.formatMinorUnitsForCode(
                      row.debtMinor,
                      row.currencyCode,
                    );
                    final paymentAmt = MoneyUtil.formatMinorUnitsForCode(
                      row.paymentMinor,
                      row.currencyCode,
                    );
                    final line = stage(
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: AppDimensions.spacingXs,
                        ),
                        child: Text(
                          l10n.closingRitualReportTotals(
                            row.currencyCode,
                            debt,
                            paymentAmt,
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: inkSecondary,
                          ),
                        ),
                      ),
                      delay: Duration(milliseconds: 520 + index * 60),
                    );
                    return line;
                  },
                ),
              ],
              const Gap(AppDimensions.spacingMd),
              stage(
                switch (result.backupStatus) {
                  ClosingBackupStatus.skippedUnsigned =>
                    DaftarPermissionBanner(
                      message: l10n.closingRitualBackupUnsigned,
                      actionLabel: l10n.backupDriveSignInWithGoogle,
                      onAction: widget.onSignInToDrive,
                      semanticsLabel:
                          l10n.closingAgentPermissionBannerSemantics,
                    ),
                  ClosingBackupStatus.grantRequired =>
                    DaftarPermissionBanner(
                      message: l10n.closingRitualBackupGrantMissing,
                      actionLabel: l10n.backupDriveOfflineGrantAction,
                      onAction: widget.onGrantDrive,
                      semanticsLabel:
                          l10n.closingAgentPermissionBannerSemantics,
                    ),
                  _ => Text(
                      _backupLine(l10n, result.backupStatus),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: result.needsHuman ? warning : payment,
                      ),
                    ),
                },
                delay: const Duration(milliseconds: 700),
              ),
              const Gap(AppDimensions.spacingSm),
              stage(
                Text(
                  l10n.closingRitualOverdueCount(result.overdueCount),
                  style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
                ),
                delay: const Duration(milliseconds: 780),
              ),
              if (result.queueMetrics case final metrics?) ...[
                const Gap(AppDimensions.spacingSm),
                stage(
                  Text(
                    l10n.closingRitualQueuePrepared(metrics.prepared),
                    style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
                  ),
                  delay: const Duration(milliseconds: 860),
                ),
                stage(
                  Text(
                    l10n.closingRitualQueueSent(metrics.sent),
                    style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
                  ),
                  delay: const Duration(milliseconds: 920),
                ),
                stage(
                  Text(
                    l10n.closingRitualQueueFailed(metrics.failed),
                    style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
                  ),
                  delay: const Duration(milliseconds: 980),
                ),
                if (metrics.opened > 0)
                  stage(
                    Text(
                      l10n.closingRitualQueueOpened(metrics.opened),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                    delay: const Duration(milliseconds: 1040),
                  ),
                stage(
                  Text(
                    l10n.closingRitualQueueSkipped(metrics.skipped),
                    style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                  ),
                  delay: const Duration(milliseconds: 1100),
                ),
              ],
              const Gap(AppDimensions.spacingSm),
              stage(
                Text(
                  _outcomeLine(l10n, result),
                  style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
                ),
                delay: const Duration(milliseconds: 1180),
              ),
              stage(
                Text(
                  _reminderLine(l10n, result.reminderPolicy),
                  style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                ),
                delay: const Duration(milliseconds: 1240),
              ),
              stage(
                Text(
                  _pdfLine(l10n, result.pdfPolicy),
                  style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
                ),
                delay: const Duration(milliseconds: 1300),
              ),
              if (result.needsHuman) ...[
                const Gap(AppDimensions.spacingMd),
                stage(
                  Text(
                    l10n.closingRitualNeedsHuman,
                    style: AppTextStyles.bodyMedium.copyWith(color: warning),
                  ),
                  delay: const Duration(milliseconds: 1360),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _backupLine(AppLocalizations l10n, ClosingBackupStatus status) {
    switch (status) {
      case ClosingBackupStatus.uploaded:
        return l10n.closingRitualBackupUploaded;
      case ClosingBackupStatus.queued:
        return l10n.backupDriveOffline;
      case ClosingBackupStatus.skippedUnsigned:
        return l10n.closingRitualBackupUnsigned;
      case ClosingBackupStatus.grantRequired:
        return l10n.closingRitualBackupGrantMissing;
      case ClosingBackupStatus.failed:
        return l10n.backupFailed;
    }
  }

  String _outcomeLine(AppLocalizations l10n, ClosingRitualResult result) {
    if (result.shortlist.isEmpty) {
      return l10n.closingRitualEmptyOverdue;
    }
    if (result.reminderPolicy == ClosingReminderPolicy.none) {
      return l10n.closingRitualSkipAll;
    }
    return l10n.closingRitualOverdueCount(result.reminderSet.length);
  }

  String _reminderLine(AppLocalizations l10n, ClosingReminderPolicy policy) {
    switch (policy) {
      case ClosingReminderPolicy.all:
        return l10n.closingRitualReminderAll;
      case ClosingReminderPolicy.top5:
        return l10n.closingRitualReminderTop5;
      case ClosingReminderPolicy.none:
        return l10n.closingRitualReminderNone;
    }
  }

  String _pdfLine(AppLocalizations l10n, ClosingPdfPolicy policy) {
    switch (policy) {
      case ClosingPdfPolicy.none:
        return l10n.closingRitualPdfNone;
      case ClosingPdfPolicy.selective:
        return l10n.closingRitualPdfSelective;
      case ClosingPdfPolicy.allInSet:
        return l10n.closingRitualPdfAll;
      case ClosingPdfPolicy.rankedTop5:
        return l10n.closingRitualPdfRankedTop5;
    }
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.unit,
    required this.count,
    required this.inkPrimary,
    required this.reduceMotion,
  });

  final String unit;
  final int count;
  final Color inkPrimary;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedFlipCounter(
          value: count.toDouble(),
          duration: reduceMotion
              ? Duration.zero
              : AppDimensions.animationXSlow,
          curve: AppMotion.curveEmphasized,
          textStyle: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
          wholeDigits: 4,
        ),
        const Gap(AppDimensions.spacingXs),
        Text(
          unit,
          style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
        ),
      ],
    );
  }
}

class _VerifiedSealCheckPainter extends CustomPainter {
  const _VerifiedSealCheckPainter({
    required this.isDark,
    required this.progress,
  });

  final bool isDark;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.34);

    final metrics = path.computeMetrics().first;
    final drawLength = metrics.length * progress.clamp(0.0, 1.0);
    final trimmed = metrics.extractPath(0, drawLength);

    final paint = Paint()
      ..color = lapis
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(trimmed, paint);
  }

  @override
  bool shouldRepaint(covariant _VerifiedSealCheckPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.progress != progress;
  }
}

class _HeroCatchPainter extends CustomPainter {
  const _HeroCatchPainter({required this.isDark, required this.progress});

  final bool isDark;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final paint = Paint()
      ..color = lapis.withValues(alpha: (1 - progress) * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const inset = 1.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    final sweep = progress * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _HeroCatchPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.progress != progress;
  }
}
