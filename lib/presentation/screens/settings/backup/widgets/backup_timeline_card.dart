import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_relative_date.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Single backup snapshot plate for the timeline carousel.
class BackupTimelineCard extends StatelessWidget {
  const BackupTimelineCard({
    required this.meta,
    required this.l10n,
    required this.isLatest,
    super.key,
  });

  final BackupMetadata meta;
  final AppLocalizations l10n;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final dt = meta.createdAt.toLocal();
    final absoluteStr =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final relativeStr = formatBackupRelativeDate(l10n, meta.createdAt);
    final sizeStr = formatBackupSize(l10n, meta.sizeBytes);

    return DaftarCard(
      padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLatest) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface4 : AppColors.surface2Light,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderSubtle
                        : AppColors.borderSubtleLight,
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.spacingSm,
                    vertical: AppDimensions.spacingXxs,
                  ),
                  child: Text(
                    l10n.backupTimelineLatest,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.payment,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            const Gap(AppDimensions.spacingMd),
          ],
          Text(
            relativeStr,
            style: AppTextStyles.titleMedium.copyWith(
              color: inkPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(AppDimensions.spacingXxs),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              absoluteStr,
              style: AppTextStyles.amountSmall.copyWith(
                color: inkSecondary,
              ),
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 18,
                color: inkMuted,
              ),
              const Gap(AppDimensions.spacingSm),
              Text(
                sizeStr,
                style: AppTextStyles.labelLarge.copyWith(
                  color: inkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
