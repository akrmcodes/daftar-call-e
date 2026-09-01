import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Inline status banners for Drive sync state.
class DriveStatusBanners extends StatelessWidget {
  const DriveStatusBanners({
    required this.l10n,
    required this.syncView,
    required this.onSignIn,
    required this.onRetryQueue,
    this.isTransferring = false,
    super.key,
  });

  final AppLocalizations l10n;
  final BackupSyncStatusView syncView;
  final VoidCallback onSignIn;
  final VoidCallback onRetryQueue;
  final bool isTransferring;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final children = <Widget>[];

    if (syncView.driveRetryScheduled) {
      children.add(
        DriveBanner(
          background: AppColors.warning.withValues(alpha: 0.12),
          border: AppColors.warning.withValues(alpha: 0.35),
          icon: Icons.schedule_rounded,
          iconColor: AppColors.warning,
          message: l10n.backupDrivePendingRetry,
          actionLabel: l10n.backupDriveRetryNow,
          onAction: onRetryQueue,
          inkPrimary: inkPrimary,
        ),
      );
    }

    switch (syncView.surface) {
      case BackupSyncSurfaceState.quotaExceeded:
        children.add(
          DriveBanner(
            background: AppColors.warningContainer.withValues(alpha: 0.5),
            border: AppColors.warning.withValues(alpha: 0.4),
            icon: Icons.storage_rounded,
            iconColor: AppColors.warning,
            message: l10n.backupDriveQuotaExceeded,
            inkPrimary: inkPrimary,
          ),
        );
      case BackupSyncSurfaceState.needsReauth:
        children.add(
          DriveBanner(
            background: AppColors.errorContainer.withValues(alpha: 0.35),
            border: AppColors.error.withValues(alpha: 0.35),
            icon: Icons.lock_reset_rounded,
            iconColor: AppColors.error,
            message: l10n.backupDriveAuthExpired,
            actionLabel: l10n.backupDriveSignInAgain,
            onAction: onSignIn,
            inkPrimary: inkPrimary,
          ),
        );
      case BackupSyncSurfaceState.offline:
        children.add(
          DriveBanner(
            background: isDark
                ? AppColors.surface4
                : AppColors.surface2Light,
            border: isDark
                ? AppColors.borderSubtle
                : AppColors.borderSubtleLight,
            icon: Icons.wifi_off_rounded,
            iconColor: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
            message: l10n.backupDriveOffline,
            inkPrimary: inkPrimary,
          ),
        );
      case BackupSyncSurfaceState.syncing:
        if (!isTransferring) {
          children.add(
            DriveBanner(
              background: isDark
                  ? AppColors.surface4
                  : AppColors.surface2Light,
              border: isDark
                  ? AppColors.borderSubtle
                  : AppColors.borderSubtleLight,
              icon: Icons.cloud_sync_rounded,
              iconColor: isDark ? AppColors.inkMuted : AppColors.inkMutedLight,
              message: l10n.cloudSyncStatusSyncing,
              inkPrimary: inkPrimary,
            ),
          );
        }
      case BackupSyncSurfaceState.synced:
        break;
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Gap(AppDimensions.spacingSm),
          children[i],
        ],
      ],
    );
  }
}

class DriveBanner extends StatelessWidget {
  const DriveBanner({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.message,
    required this.inkPrimary,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
    super.key,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String message;
  final Color inkPrimary;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingLg,
          vertical: AppDimensions.spacingMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  height: 1.45,
                  color: inkPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const Gap(AppDimensions.spacingSm),
              TextButton(
                onPressed: actionLoading ? null : onAction,
                child: actionLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: inkPrimary,
                        ),
                      )
                    : Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
