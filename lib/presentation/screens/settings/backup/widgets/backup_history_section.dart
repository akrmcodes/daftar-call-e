import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_timeline_carousel.dart';
import 'package:daftar/presentation/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Backup history — focal timeline carousel, skeleton, or empty state.
class BackupHistorySection extends StatelessWidget {
  const BackupHistorySection({
    required this.backups,
    required this.isLoading,
    required this.isRestoring,
    required this.onShare,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final List<BackupMetadata> backups;
  final bool isLoading;
  final bool isRestoring;
  final void Function(BackupMetadata meta) onShare;
  final void Function(BackupMetadata meta) onRestore;
  final void Function(BackupMetadata meta) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppDimensions.pagePaddingH,
            end: AppDimensions.pagePaddingH,
            bottom: AppDimensions.spacingMd,
          ),
          child: Text(
            l10n.backupHistory,
            style: AppTextStyles.titleMedium.copyWith(
              color: inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.pagePaddingH,
            ),
            child: Skeletonizer(
              child: Column(
                children: [
                  _BackupHistorySkeletonRow(),
                  _BackupHistorySkeletonRow(),
                  _BackupHistorySkeletonRow(),
                ],
              ),
            ),
          )
        else if (backups.isEmpty)
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: l10n.backupNoHistory,
            subtitle: l10n.backupStatusNoBackupSubtitle,
          )
        else
          BackupTimelineCarousel(
            backups: backups,
            isRestoring: isRestoring,
            onShare: onShare,
            onRestore: onRestore,
            onDelete: onDelete,
          ),
        const Gap(AppDimensions.spacingMd),
      ],
    );
  }
}

class _BackupHistorySkeletonRow extends StatelessWidget {
  const _BackupHistorySkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppDimensions.spacingMd),
      child: Row(
        children: [
          Bone.circle(size: 44),
          Gap(AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 3),
                Gap(4),
                Bone.text(words: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
