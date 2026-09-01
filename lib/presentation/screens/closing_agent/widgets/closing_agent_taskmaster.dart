import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_task_id.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_vault_chrome.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Plan review, execution log, or sealed rail for close-the-day.
enum ClosingAgentTaskmasterMode {
  /// Merchant approves the device-owned checklist.
  planReview,

  /// Ritual in progress — rows light up as work completes.
  executing,

  /// Slim continuity rail above the ceremonial report.
  sealed,

  /// Desk phase — slim rail + current step only (no scroll list).
  compact,
}

/// Row visual state for one [ClosingTaskId].
enum _ClosingTaskRowState {
  pending,
  current,
  done,
  skipped,
  failed,
  blocked,
}

/// Unified close-the-day taskmaster (plan = execution log).
class ClosingAgentTaskmaster extends StatefulWidget {
  /// Creates the taskmaster.
  const ClosingAgentTaskmaster({
    required this.mode,
    this.localDay,
    this.tasksDone = const {},
    this.tasksSkipped = const {},
    this.taskCurrent,
    this.summary,
    this.overdueCount = 0,
    this.backupStatus,
    this.backupFailed = false,
    this.deskBlocked = false,
    this.showActions = false,
    this.isConfirming = false,
    this.approveIsPrimary = true,
    this.onConfirmAndSend,
    this.onConfirmWithoutSending,
    this.onSkip,
    super.key,
  });

  /// Plan review, executing, or sealed rail.
  final ClosingAgentTaskmasterMode mode;

  /// Merchant calendar day chip (e.g. `2026-08-24`).
  final String? localDay;

  /// Completed ritual tasks.
  final Set<ClosingTaskId> tasksDone;

  /// Skipped tasks (e.g. desk when no overdue).
  final Set<ClosingTaskId> tasksSkipped;

  /// Task currently in progress.
  final ClosingTaskId? taskCurrent;

  /// Day summary for live captions.
  final ClosingDaySummary? summary;

  /// Overdue account count for captions.
  final int overdueCount;

  /// Drive backup outcome for the seal row caption.
  final ClosingBackupStatus? backupStatus;

  /// When true, [ClosingTaskId.sealDriveBackup] shows failed styling.
  final bool backupFailed;

  /// When true, [ClosingTaskId.openCollectionsDesk] shows blocked styling.
  final bool deskBlocked;

  /// When true, show Confirm & send + Confirm without sending (plan review).
  final bool showActions;

  /// Confirm button shows spinner.
  final bool isConfirming;

  /// Confirm & send owns the single lapis glow.
  final bool approveIsPrimary;

  /// Confirms the plan and consents to SMTP outreach.
  final VoidCallback? onConfirmAndSend;

  /// Confirms the plan and closes books with no email.
  final VoidCallback? onConfirmWithoutSending;

  /// Skips the closing plan without starting the ritual.
  final VoidCallback? onSkip;

  @override
  State<ClosingAgentTaskmaster> createState() => _ClosingAgentTaskmasterState();
}

class _ClosingAgentTaskmasterState extends State<ClosingAgentTaskmaster>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _rowKeys = <ClosingTaskId, GlobalKey>{};

  late final AnimationController _gleamController;
  ClosingTaskId? _lastScrolledCurrent;

  @override
  void initState() {
    super.initState();
    for (final id in ClosingTaskOrder.ordered) {
      _rowKeys[id] = GlobalKey();
    }
    _gleamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  bool get _reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      SchedulerBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  bool get _shouldAnimateGleam =>
      !_reduceMotion &&
      widget.mode == ClosingAgentTaskmasterMode.executing &&
      widget.taskCurrent != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncGleam();
  }

  @override
  void didUpdateWidget(covariant ClosingAgentTaskmaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGleam();
    if (widget.taskCurrent != null &&
        widget.taskCurrent != _lastScrolledCurrent &&
        widget.mode == ClosingAgentTaskmasterMode.executing) {
      _lastScrolledCurrent = widget.taskCurrent;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  void _syncGleam() {
    if (_shouldAnimateGleam) {
      if (!_gleamController.isAnimating) {
        unawaited(_gleamController.repeat());
      }
    } else {
      _gleamController.stop();
    }
  }

  Future<void> _scrollToCurrent() async {
    final current = widget.taskCurrent;
    if (current == null) {
      return;
    }
    final key = _rowKeys[current];
    final context = key?.currentContext;
    if (context == null || !mounted) {
      return;
    }
    await Scrollable.ensureVisible(
      context,
      alignment: 0.35,
      duration: _reduceMotion ? Duration.zero : AppDimensions.animationFast,
      curve: AppMotion.curveStandard,
    );
  }

  @override
  void dispose() {
    _gleamController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ClosingTaskRowState _rowState(ClosingTaskId id) {
    if (widget.mode == ClosingAgentTaskmasterMode.planReview) {
      return _ClosingTaskRowState.pending;
    }
    if (widget.tasksDone.contains(id)) {
      return _ClosingTaskRowState.done;
    }
    if (widget.tasksSkipped.contains(id)) {
      return _ClosingTaskRowState.skipped;
    }
    if (id == ClosingTaskId.sealDriveBackup &&
        widget.backupFailed &&
        widget.tasksDone.contains(id)) {
      return _ClosingTaskRowState.failed;
    }
    if (widget.taskCurrent == id) {
      if (id == ClosingTaskId.openCollectionsDesk && widget.deskBlocked) {
        return _ClosingTaskRowState.blocked;
      }
      return _ClosingTaskRowState.current;
    }
    return _ClosingTaskRowState.pending;
  }

  int get _sealedCount {
    if (widget.mode == ClosingAgentTaskmasterMode.sealed) {
      return ClosingTaskOrder.ordered.length - widget.tasksSkipped.length;
    }
    return widget.tasksDone.length;
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

    final isSealed = widget.mode == ClosingAgentTaskmasterMode.sealed;
    final isCompact = widget.mode == ClosingAgentTaskmasterMode.compact;
    final isPlanReview = widget.mode == ClosingAgentTaskmasterMode.planReview;
    const tasks = ClosingTaskOrder.ordered;
    final vaultChrome = ClosingAgentVaultChrome(
      enableBreath: isPlanReview && isDark,
      child: _buildBody(
        l10n: l10n,
        isDark: isDark,
        inkPrimary: inkPrimary,
        inkSecondary: inkSecondary,
        isSealed: isSealed,
        isCompact: isCompact,
        isPlanReview: isPlanReview,
        tasks: tasks,
      ),
    );

    if (isCompact) {
      return RepaintBoundary(child: vaultChrome);
    }

    return RepaintBoundary(child: vaultChrome);
  }

  Widget _buildBody({
    required AppLocalizations l10n,
    required bool isDark,
    required Color inkPrimary,
    required Color inkSecondary,
    required bool isSealed,
    required bool isCompact,
    required bool isPlanReview,
    required List<ClosingTaskId> tasks,
  }) {
    if (isCompact) {
      final current = widget.taskCurrent;
      final caption = current != null ? _liveCaption(l10n, current) : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.localDay != null && widget.localDay!.isNotEmpty) ...[
                _DayChip(label: widget.localDay!, isDark: isDark),
                const Gap(AppDimensions.spacingSm),
              ],
              Expanded(
                child: Text(
                  l10n.closingAgentTaskmasterTitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppDimensions.spacingSm),
          _SealedRail(
            tasksDone: widget.tasksDone,
            tasksSkipped: widget.tasksSkipped,
            taskCurrent: widget.taskCurrent,
            deskBlocked: widget.deskBlocked,
            isDark: isDark,
          ),
          if (current != null) ...[
            const Gap(AppDimensions.spacingSm),
            Text(
              _taskTitle(l10n, current),
              style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
            ),
            if (caption != null && caption.isNotEmpty)
              Text(
                caption,
                style: AppTextStyles.bodySmall.copyWith(
                  color: inkSecondary,
                ),
              ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.localDay != null && widget.localDay!.isNotEmpty) ...[
              _DayChip(label: widget.localDay!, isDark: isDark),
              const Gap(AppDimensions.spacingSm),
            ],
            Expanded(
              child: Text(
                isSealed
                    ? l10n.closingTaskmasterSealed(_sealedCount)
                    : l10n.closingAgentTaskmasterTitle,
                style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
              ),
            ),
            if (isPlanReview && widget.onSkip != null)
              DaftarButton(
                label: l10n.closingAgentSkip,
                variant: DaftarButtonVariant.tertiary,
                size: DaftarButtonSize.small,
                onPressed: widget.isConfirming ? null : widget.onSkip,
              ),
          ],
        ),
        if (!isSealed) ...[
          const Gap(AppDimensions.spacingXs),
          Text(
            l10n.closingAgentPlanDeviceRuns,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
          if (isPlanReview) ...[
            const Gap(AppDimensions.spacingXs),
            Text(
              l10n.closingAgentPlanSendSplit,
              style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
            ),
            const Gap(AppDimensions.spacingXs),
            Text(
              l10n.closingAgentPlanOutreachConsent,
              style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
            ),
          ],
        ],
        const Gap(AppDimensions.spacingMd),
        if (isSealed)
          _SealedRail(
            tasksDone: widget.tasksDone,
            tasksSkipped: widget.tasksSkipped,
            isDark: isDark,
          )
        else if (widget.mode == ClosingAgentTaskmasterMode.executing)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: _TaskList(
              scrollController: _scrollController,
              tasks: tasks,
              isDark: isDark,
              rowState: _rowState,
              taskTitle: _taskTitle,
              liveCaption: _liveCaption,
              gleamController: _gleamController,
              reduceMotion: _reduceMotion,
              rowKeys: _rowKeys,
            ),
          )
        else
          _TaskList(
            scrollController: _scrollController,
            tasks: tasks,
            isDark: isDark,
            rowState: _rowState,
            taskTitle: _taskTitle,
            liveCaption: _liveCaption,
            gleamController: _gleamController,
            reduceMotion: _reduceMotion,
            rowKeys: _rowKeys,
            entranceStagger: true,
          ),
        if (widget.showActions) ...[
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: l10n.closingAgentConfirmAndSend,
            variant: widget.approveIsPrimary
                ? DaftarButtonVariant.primary
                : DaftarButtonVariant.secondary,
            isExpanded: true,
            isLoading: widget.isConfirming,
            onPressed: widget.isConfirming ? null : widget.onConfirmAndSend,
          ),
          const Gap(AppDimensions.spacingSm),
          DaftarButton(
            label: l10n.closingAgentConfirmWithoutSending,
            variant: DaftarButtonVariant.secondary,
            isExpanded: true,
            onPressed: widget.isConfirming
                ? null
                : widget.onConfirmWithoutSending,
          ),
        ],
      ],
    );
  }

  String _taskTitle(AppLocalizations l10n, ClosingTaskId id) {
    return switch (id) {
      ClosingTaskId.bindLedger => l10n.closingTaskBindLedger,
      ClosingTaskId.collectDebts => l10n.closingTaskCollectDebts,
      ClosingTaskId.collectPayments => l10n.closingTaskCollectPayments,
      ClosingTaskId.tallyTotals => l10n.closingTaskTallyTotals,
      ClosingTaskId.stampSnapshot => l10n.closingTaskStampSnapshot,
      ClosingTaskId.prepareVaultPayload => l10n.closingTaskPrepareVault,
      ClosingTaskId.sealDriveBackup => l10n.closingTaskSealDrive,
      ClosingTaskId.scanAging => l10n.closingTaskScanAging,
      ClosingTaskId.rankUrgency => l10n.closingTaskRankUrgency,
      ClosingTaskId.buildSendSet => l10n.closingTaskBuildSendSet,
      ClosingTaskId.openCollectionsDesk => l10n.closingTaskOpenDesk,
      ClosingTaskId.composeReport => l10n.closingTaskComposeReport,
      ClosingTaskId.presentSeal => l10n.closingTaskPresentSeal,
    };
  }

  String? _liveCaption(AppLocalizations l10n, ClosingTaskId id) {
    final summary = widget.summary;
    return switch (id) {
      ClosingTaskId.collectDebts when summary != null =>
        l10n.closingTaskCaptionDebts(summary.debtCount),
      ClosingTaskId.collectPayments when summary != null =>
        l10n.closingTaskCaptionPayments(summary.paymentCount),
      ClosingTaskId.tallyTotals when summary != null =>
        l10n.closingTaskCaptionCurrencies(summary.totals.length),
      ClosingTaskId.buildSendSet => l10n.closingTaskCaptionSendSet(
        math.min(20, widget.overdueCount),
      ),
      ClosingTaskId.scanAging || ClosingTaskId.rankUrgency =>
        l10n.closingTaskCaptionOverdue(widget.overdueCount),
      ClosingTaskId.sealDriveBackup when widget.backupStatus != null =>
        _backupCaption(l10n, widget.backupStatus!),
      ClosingTaskId.openCollectionsDesk when widget.deskBlocked =>
        l10n.closingTaskCaptionSendAuth,
      ClosingTaskId.openCollectionsDesk => l10n.closingTaskCaptionOverdue(
        widget.overdueCount,
      ),
      _ => null,
    };
  }

  String _backupCaption(AppLocalizations l10n, ClosingBackupStatus status) {
    return switch (status) {
      ClosingBackupStatus.uploaded => l10n.closingRitualBackupUploaded,
      ClosingBackupStatus.queued => l10n.backupDriveOffline,
      ClosingBackupStatus.skippedUnsigned => l10n.closingRitualBackupUnsigned,
      ClosingBackupStatus.grantRequired => l10n.closingRitualBackupGrantMissing,
      ClosingBackupStatus.failed => l10n.backupFailed,
    };
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.scrollController,
    required this.tasks,
    required this.isDark,
    required this.rowState,
    required this.taskTitle,
    required this.liveCaption,
    required this.gleamController,
    required this.reduceMotion,
    required this.rowKeys,
    this.entranceStagger = false,
  });

  final ScrollController scrollController;
  final List<ClosingTaskId> tasks;
  final bool isDark;
  final _ClosingTaskRowState Function(ClosingTaskId id) rowState;
  final String Function(AppLocalizations l10n, ClosingTaskId id) taskTitle;
  final String? Function(AppLocalizations l10n, ClosingTaskId id) liveCaption;
  final AnimationController gleamController;
  final bool reduceMotion;
  final Map<ClosingTaskId, GlobalKey> rowKeys;
  final bool entranceStagger;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: gleamController,
      builder: (context, _) {
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: tasks.length > 8,
          child: ListView.builder(
            controller: scrollController,
            shrinkWrap: true,
            physics: entranceStagger
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final id = tasks[index];
              final state = rowState(id);
              final isLast = index == tasks.length - 1;
              final delay = entranceStagger
                  ? Duration(milliseconds: index < 8 ? index * 30 : 0)
                  : Duration.zero;
              return FadeSlideTransition(
                delay: delay,
                child: KeyedSubtree(
                  key: rowKeys[id],
                  child: _TaskRow(
                    title: taskTitle(l10n, id),
                    caption:
                        state == _ClosingTaskRowState.current ||
                            state == _ClosingTaskRowState.blocked
                        ? liveCaption(l10n, id)
                        : null,
                    state: state,
                    isDark: isDark,
                    showRailBelow: !isLast,
                    gleamPhase:
                        state == _ClosingTaskRowState.current && !reduceMotion
                        ? gleamController.value
                        : 0,
                    reduceMotion: reduceMotion,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXxs,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
        ),
      ),
    );
  }
}

class _SealedRail extends StatelessWidget {
  const _SealedRail({
    required this.tasksDone,
    required this.tasksSkipped,
    required this.isDark,
    this.taskCurrent,
    this.deskBlocked = false,
  });

  final Set<ClosingTaskId> tasksDone;
  final Set<ClosingTaskId> tasksSkipped;
  final bool isDark;
  final ClosingTaskId? taskCurrent;
  final bool deskBlocked;

  @override
  Widget build(BuildContext context) {
    final payment = isDark ? AppColors.payment : AppColors.paymentLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;

    return SizedBox(
      height: AppDimensions.iconMedium,
      child: Row(
        children: [
          for (var i = 0; i < ClosingTaskOrder.ordered.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 1.5,
                  color:
                      tasksDone.contains(ClosingTaskOrder.ordered[i - 1]) ||
                          tasksSkipped.contains(ClosingTaskOrder.ordered[i - 1])
                      ? payment.withValues(alpha: 0.45)
                      : inkMuted.withValues(alpha: 0.25),
                ),
              ),
            Builder(
              builder: (context) {
                final id = ClosingTaskOrder.ordered[i];
                final isCurrent = taskCurrent == id;
                final isBlocked =
                    isCurrent &&
                    deskBlocked &&
                    id == ClosingTaskId.openCollectionsDesk;
                if (tasksDone.contains(id)) {
                  return Icon(Icons.check_rounded, size: 8, color: payment);
                }
                if (tasksSkipped.contains(id)) {
                  return Icon(Icons.remove_rounded, size: 8, color: inkMuted);
                }
                if (isCurrent) {
                  return Icon(
                    isBlocked ? Icons.hourglass_top_rounded : Icons.circle,
                    size: isBlocked ? 10 : 8,
                    color: isBlocked ? warning : lapis,
                  );
                }
                return Icon(Icons.circle, size: 8, color: inkMuted);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.title,
    required this.caption,
    required this.state,
    required this.isDark,
    required this.showRailBelow,
    required this.gleamPhase,
    required this.reduceMotion,
  });

  final String title;
  final String? caption;
  final _ClosingTaskRowState state;
  final bool isDark;
  final bool showRailBelow;
  final double gleamPhase;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final payment = isDark ? AppColors.payment : AppColors.paymentLight;
    final debt = isDark ? AppColors.debt : AppColors.debtLight;

    final titleColor = switch (state) {
      _ClosingTaskRowState.pending => inkMuted,
      _ClosingTaskRowState.skipped => inkMuted,
      _ClosingTaskRowState.current => inkPrimary,
      _ClosingTaskRowState.blocked => inkPrimary,
      _ => inkPrimary,
    };
    final titleWeight = switch (state) {
      _ClosingTaskRowState.current => FontWeight.w600,
      _ClosingTaskRowState.blocked => FontWeight.w600,
      _ => FontWeight.w400,
    };

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingSm,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppDimensions.iconMedium + 4,
              child: Column(
                children: [
                  _Node(
                    state: state,
                    isDark: isDark,
                    payment: payment,
                    debt: debt,
                    inkMuted: inkMuted,
                    reduceMotion: reduceMotion,
                  ),
                  if (showRailBelow)
                    Expanded(
                      child: CustomPaint(
                        painter: _RailPainter(
                          isDark: isDark,
                          isActive:
                              state == _ClosingTaskRowState.current ||
                              state == _ClosingTaskRowState.blocked,
                          isDone: state == _ClosingTaskRowState.done,
                          gleamPhase: gleamPhase,
                        ),
                        size: const Size(1.5, double.infinity),
                      ),
                    ),
                ],
              ),
            ),
            const Gap(AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: titleColor,
                      fontWeight: titleWeight,
                    ),
                  ),
                  if (caption != null && caption!.isNotEmpty)
                    Text(
                      caption!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.state,
    required this.isDark,
    required this.payment,
    required this.debt,
    required this.inkMuted,
    required this.reduceMotion,
  });

  final _ClosingTaskRowState state;
  final bool isDark;
  final Color payment;
  final Color debt;
  final Color inkMuted;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const size = AppDimensions.iconMedium;

    if (state == _ClosingTaskRowState.done) {
      final icon = Icon(
        Icons.check_rounded,
        size: size,
        color: payment,
      );
      if (reduceMotion) {
        return icon;
      }
      return icon.animate().scale(
        begin: const Offset(0.6, 0.6),
        end: const Offset(1, 1),
        duration: AppDimensions.animationFast,
        curve: AppMotion.curveSpring,
      );
    }

    if (state == _ClosingTaskRowState.failed) {
      return Icon(Icons.error_outline_rounded, size: size, color: debt);
    }

    if (state == _ClosingTaskRowState.skipped) {
      return Icon(Icons.remove_rounded, size: size, color: inkMuted);
    }

    if (state == _ClosingTaskRowState.blocked) {
      final warning = isDark ? AppColors.warning : AppColors.warningLight;
      return Icon(Icons.hourglass_top_rounded, size: size, color: warning);
    }

    if (state == _ClosingTaskRowState.current) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.lapis400 : AppColors.lapis500,
              width: 1.5,
            ),
          ),
        ),
      );
    }

    return Icon(Icons.circle_outlined, size: size * 0.55, color: inkMuted);
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.isDark,
    required this.isActive,
    required this.isDone,
    required this.gleamPhase,
  });

  final bool isDark;
  final bool isActive;
  final bool isDone;
  final double gleamPhase;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      track,
    );

    if (isDone) {
      final done = Paint()
        ..color = (isDark ? AppColors.payment : AppColors.paymentLight)
            .withValues(alpha: 0.5)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        done,
      );
    }

    if (isActive && gleamPhase > 0) {
      final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;
      final gleamY = size.height * gleamPhase;
      final gleamHeight = size.height * 0.18;
      final start = (gleamY - gleamHeight).clamp(0.0, size.height);
      final end = (gleamY + gleamHeight * 0.25).clamp(0.0, size.height);
      final gleam = Paint()
        ..color = lapis.withValues(alpha: 0.85)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width / 2, start),
        Offset(size.width / 2, end),
        gleam,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.isActive != isActive ||
        oldDelegate.isDone != isDone ||
        oldDelegate.gleamPhase != gleamPhase;
  }
}
