import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/domain/entities/merge_conflict.dart';
import 'package:daftar/domain/entities/sync_status.dart';
import 'package:daftar/domain/enums/conflict_type.dart';
import 'package:daftar/domain/enums/sync_result_type.dart';
import 'package:daftar/presentation/providers/sync_engine_providers.dart';
import 'package:daftar/presentation/providers/sync_providers.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sync Report screen showing sync status, merged ops, and conflicts.
///
/// Khazna v3 Lapis Lux design: monochrome canvas, lapis glow borders,
/// semantic colors for conflict states.
class SyncReportScreen extends ConsumerWidget {
  const SyncReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatusAsync = ref.watch(syncStatusProvider);
    final conflictsAsync = ref.watch(unresolvedConflictsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface1 : AppColors.surface0Light,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surface2 : AppColors.surface1Light,
        title: Text(
          l10n.syncReportTitle,
          style: AppTextStyles.headlineLarge.copyWith(
            color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: syncStatusAsync.when(
          data: (status) => _SyncReportBody(
            status: status,
            conflictsAsync: conflictsAsync,
            isDark: isDark,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              l10n.syncReportStatusLoadFailed,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark ? AppColors.debt : AppColors.debtLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncReportBody extends ConsumerStatefulWidget {
  const _SyncReportBody({
    required this.status,
    required this.conflictsAsync,
    required this.isDark,
  });

  final SyncStatus status;
  final AsyncValue<List<MergeConflict>> conflictsAsync;
  final bool isDark;

  @override
  ConsumerState<_SyncReportBody> createState() => _SyncReportBodyState();
}

class _SyncReportBodyState extends ConsumerState<_SyncReportBody> {
  bool _syncInProgress = false;
  bool _uploadInProgress = false;
  bool _downloadInProgress = false;

  bool get _anyInProgress =>
      _syncInProgress || _uploadInProgress || _downloadInProgress;

  String _failureMessage(AppLocalizations l10n, Failure failure) {
    // Transport-level diagnostics that carry no server code: the local dev
    // stack being unreachable is a developer-facing case with its own hint.
    final lowerMessage = failure.message.toLowerCase();
    if (lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection errored')) {
      return l10n.syncReportConnectionRefused;
    }

    const authBridgeCodes = {
      'sync_auth_failed',
      'sync_bridge_blocked',
      'sync_token_missing',
      'sync_id_token_missing',
    };
    if (authBridgeCodes.contains(failure.code)) {
      return l10n.syncAuthBridgeFailed;
    }
    if (failure.code == 'sync_in_flight') {
      return l10n.syncReportSyncNowInProgress;
    }
    // Never fall back to Failure.message — it is an English engineering
    // diagnostic, not copy a merchant can act on.
    return ErrorTranslator.message(l10n, failure);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onSyncNow() async {
    if (_anyInProgress) {
      return;
    }
    setState(() => _syncInProgress = true);
    try {
      final result =
          await ref.read(syncEngineControllerProvider.notifier).syncNow();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      result.fold(
        (failure) => _showSnack(_failureMessage(l10n, failure)),
        (_) {
          ref
            ..invalidate(syncStatusProvider)
            ..invalidate(unresolvedConflictsProvider);
        },
      );
    } finally {
      if (mounted) {
        setState(() => _syncInProgress = false);
      }
    }
  }

  Future<void> _onUpload() async {
    if (_anyInProgress) {
      return;
    }
    setState(() => _uploadInProgress = true);
    try {
      final result =
          await ref.read(syncEngineControllerProvider.notifier).pushNow();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      result.fold(
        (failure) => _showSnack(_failureMessage(l10n, failure)),
        (count) {
          ref.invalidate(syncStatusProvider);
          _showSnack(l10n.syncReportPushSuccess(count));
        },
      );
    } finally {
      if (mounted) {
        setState(() => _uploadInProgress = false);
      }
    }
  }

  Future<void> _onDownload() async {
    if (_anyInProgress) {
      return;
    }
    setState(() => _downloadInProgress = true);
    try {
      final result =
          await ref.read(syncEngineControllerProvider.notifier).pullNow();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      result.fold(
        (failure) => _showSnack(_failureMessage(l10n, failure)),
        (merge) {
          ref
            ..invalidate(syncStatusProvider)
            ..invalidate(unresolvedConflictsProvider);
          _showSnack(l10n.syncReportPullSuccess(merge.appliedOpCount));
        },
      );
    } finally {
      if (mounted) {
        setState(() => _downloadInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entitledAsync = ref.watch(isMultiDeviceSyncUnlockedProvider);

    return entitledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _DormantBanner(isDark: widget.isDark),
      data: (entitled) {
        if (!entitled) {
          return _DormantBanner(isDark: widget.isDark);
        }

        final l10n = AppLocalizations.of(context)!;
        final status = widget.status;
        final isDark = widget.isDark;
        final conflictsAsync = widget.conflictsAsync;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Status Card ──────────────────────────────────────────────
            _StatusCard(status: status, isDark: isDark, l10n: l10n),
            const SizedBox(height: 16),

            DaftarButton(
              label: _syncInProgress
                  ? l10n.syncReportSyncNowInProgress
                  : l10n.syncReportSyncNow,
              onPressed: _anyInProgress ? null : _onSyncNow,
              isLoading: _syncInProgress,
              isExpanded: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DaftarButton(
                    label: _uploadInProgress
                        ? l10n.syncReportUploadInProgress
                        : l10n.syncReportUpload,
                    onPressed: _anyInProgress ? null : _onUpload,
                    isLoading: _uploadInProgress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DaftarButton(
                    label: _downloadInProgress
                        ? l10n.syncReportDownloadInProgress
                        : l10n.syncReportDownload,
                    onPressed: _anyInProgress ? null : _onDownload,
                    isLoading: _downloadInProgress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Stats Row ────────────────────────────────────────────────
            _StatsRow(status: status, isDark: isDark),
            const SizedBox(height: 24),

            // ── Conflicts Section ────────────────────────────────────────
            if (status.hasConflicts) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.syncReportConflictsHeading,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: isDark
                        ? AppColors.inkPrimary
                        : AppColors.inkPrimaryLight,
                  ),
                ),
              ),
              conflictsAsync.when(
                data: (conflicts) => ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: conflicts.length,
                  itemBuilder: (_, index) => _ConflictTile(
                    conflict: conflicts[index],
                    isDark: isDark,
                  ),
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ],

            // ── No Conflicts Banner ──────────────────────────────────────
            if (!status.hasConflicts && !status.hasNeverSynced)
              _NoConflictsBanner(isDark: isDark),
          ],
        );
      },
    );
  }
}

/// Banner shown for non-Pro+ users.
class _DormantBanner extends StatelessWidget {
  const _DormantBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface2 : AppColors.surface1Light,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lapis400, width: 0.5),
            boxShadow: AppGlows.haloSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sync_disabled_rounded,
                size: 48,
                color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.syncReportDormantTitle,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: isDark
                      ? AppColors.inkPrimary
                      : AppColors.inkPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.syncReportDormantBody,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.inkSecondary
                      : AppColors.inkSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status overview card with last sync time and result.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.isDark,
    required this.l10n,
  });

  final SyncStatus status;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (status.lastSyncResult) {
      SyncResultType.success => isDark ? AppColors.payment : AppColors.paymentLight,
      SyncResultType.partial => isDark ? AppColors.warning : AppColors.warningLight,
      SyncResultType.failed => isDark ? AppColors.debt : AppColors.debtLight,
      SyncResultType.idle => isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
      SyncResultType.dormant => isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
    };

    final statusText = switch (status.lastSyncResult) {
      SyncResultType.success => l10n.syncReportStatusSuccess,
      SyncResultType.partial => l10n.syncReportStatusPartial,
      SyncResultType.failed => l10n.syncReportStatusFailed,
      SyncResultType.idle => l10n.syncReportStatusIdle,
      SyncResultType.dormant => l10n.syncReportStatusDormant,
    };

    final statusIcon = switch (status.lastSyncResult) {
      SyncResultType.success => Icons.check_circle_rounded,
      SyncResultType.partial => Icons.warning_amber_rounded,
      SyncResultType.failed => Icons.error_rounded,
      SyncResultType.idle => Icons.sync_rounded,
      SyncResultType.dormant => Icons.sync_disabled_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2 : AppColors.surface1Light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: statusColor, width: 1.5),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isDark
                        ? AppColors.inkPrimary
                        : AppColors.inkPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status.lastSyncAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(status.lastSyncAt!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d/$mo/${local.year} $h:$m';
  }
}

/// Stats row: merged ops, pending, conflicts.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.status,
    required this.isDark,
  });

  final SyncStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: l10n.syncReportStatMerged,
            value: status.mergedOpCount.toString(),
            icon: Icons.merge_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            label: l10n.syncReportStatPending,
            value: status.pendingOpCount.toString(),
            icon: Icons.hourglass_top_rounded,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            label: l10n.syncReportStatConflicts,
            value: status.conflictCount.toString(),
            icon: Icons.warning_amber_rounded,
            isDark: isDark,
            isWarning: status.hasConflicts,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final accentColor = isWarning
        ? (isDark ? AppColors.warning : AppColors.warningLight)
        : (isDark ? AppColors.inkMuted : AppColors.inkMutedLight);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface3 : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.amountMedium.copyWith(
              color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color:
                  isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Tile showing a single merge conflict.
class _ConflictTile extends StatelessWidget {
  const _ConflictTile({
    required this.conflict,
    required this.isDark,
  });

  final MergeConflict conflict;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeLabel = switch (conflict.conflictType) {
      ConflictType.deleteVsEdit => l10n.syncReportConflictDeleteVsEdit,
      ConflictType.concurrentCreate => l10n.syncReportConflictConcurrentCreate,
      ConflictType.ambiguous => l10n.syncReportConflictAmbiguous,
      ConflictType.rejectedByServer => l10n.syncReportConflictRejectedPush,
    };

    final typeIcon = switch (conflict.conflictType) {
      ConflictType.deleteVsEdit => Icons.delete_sweep_rounded,
      ConflictType.concurrentCreate => Icons.people_alt_rounded,
      ConflictType.ambiguous => Icons.help_outline_rounded,
      ConflictType.rejectedByServer => Icons.cloud_off_rounded,
    };

    final entityLabel = switch (conflict.entityType) {
      'ledger' => l10n.syncReportEntityLedger,
      'contact' => l10n.syncReportEntityContact,
      'transaction' => l10n.syncReportEntityTransaction,
      _ => conflict.entityType,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface2 : AppColors.surface1Light,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.warning.withValues(alpha: 0.3) : AppColors.warningLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.warningContainer
                    : AppColors.warningContainerLight,
              ),
              child: Icon(
                typeIcon,
                size: 20,
                color: isDark ? AppColors.onWarning : AppColors.onWarningLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$entityLabel • ${_shortId(conflict.entityId)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
            ),
          ],
        ),
      ),
    );
  }

  /// A conflict raised by a hostile op can carry an id shorter than the
  /// preview length, so never blind-slice it.
  static String _shortId(String entityId) {
    return entityId.length > 8 ? '${entityId.substring(0, 8)}…' : entityId;
  }
}

/// Banner shown when there are no conflicts.
class _NoConflictsBanner extends StatelessWidget {
  const _NoConflictsBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.paymentContainer
            : AppColors.paymentContainerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: isDark ? AppColors.payment : AppColors.paymentLight,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.syncReportNoConflicts,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.onPayment : AppColors.onPaymentLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
