import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:skeletonizer/skeletonizer.dart';

/// Formats a Drive backup item date for display.
String formatDriveBackupDate(
  BuildContext context,
  GoogleDriveRemoteBackupItem item,
) {
  final dt = item.modifiedTimeUtc?.toLocal();
  if (dt == null) {
    return item.name;
  }
  return DateFormat.yMMMd(AppConstants.numeralLocale).add_jm().format(dt);
}

class DriveRemoteTile extends StatelessWidget {
  const DriveRemoteTile({
    required this.item,
    required this.l10n,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final GoogleDriveRemoteBackupItem item;
  final AppLocalizations l10n;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final fill = isDark ? AppColors.surface3 : AppColors.surface1Light;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    final dateStr = formatDriveBackupDate(context, item);
    final sizeStr = item.sizeBytes != null && item.sizeBytes! > 0
        ? formatBackupSize(l10n, item.sizeBytes!)
        : '—';

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingSm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingXs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.backup_table_rounded,
                color: inkSecondary,
                size: 22,
              ),
              const Gap(AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        dateStr,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: inkPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      sizeStr,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              DriveBackupMoreMenu(
                l10n: l10n,
                onRestore: onRestore,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveBackupMoreMenu extends StatelessWidget {
  const DriveBackupMoreMenu({
    required this.l10n,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height,
      offset.dx + box.size.width,
      offset.dy,
    );
    final value = await showMenu<String>(
      context: context,
      position: position,
      items: [
        PopupMenuItem(
          value: 'restore',
          child: Text(l10n.backupRestore),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(l10n.backupDelete),
        ),
      ],
    );
    if (value == 'restore') {
      onRestore();
    } else if (value == 'delete') {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final menuLabel = MaterialLocalizations.of(context).showMenuTooltip;

    return Semantics(
      button: true,
      label: menuLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMenu(context),
        child: SizedBox(
          width: AppDimensions.minTapTarget,
          height: AppDimensions.minTapTarget,
          child: Icon(
            Icons.more_horiz_rounded,
            color: inkMuted,
          ),
        ),
      ),
    );
  }
}

class DriveEmptyCloudList extends StatelessWidget {
  const DriveEmptyCloudList({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingLg),
      child: Text(
        l10n.backupDriveNoCloudBackups,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: inkSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

class DriveSectionSkeleton extends StatelessWidget {
  const DriveSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        children: [
          Container(
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
        ],
      ),
    );
  }
}

class DriveAccountHeaderSkeleton extends StatelessWidget {
  const DriveAccountHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Skeletonizer(
      child: Row(
        children: [
          Bone.circle(size: 52),
          Gap(AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Bone.text(words: 2),
                Gap(6),
                Bone.text(words: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriveListSkeleton extends StatelessWidget {
  const DriveListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
