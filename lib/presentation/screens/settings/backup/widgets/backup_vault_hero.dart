import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_relative_date.dart';
import 'package:daftar/presentation/screens/settings/widgets/bento_atoms.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Khazna Vault hero — dual health rings, status copy, and primary CTA.
class BackupVaultHero extends StatelessWidget {
  const BackupVaultHero({
    required this.lastBackup,
    required this.backupCount,
    required this.totalSizeBytes,
    required this.hasLocalBackup,
    required this.isCloudSynced,
    required this.isSignedIn,
    required this.isCreating,
    required this.onCreateTap,
    super.key,
  });

  final BackupMetadata? lastBackup;
  final int backupCount;
  final int totalSizeBytes;
  final bool hasLocalBackup;
  final bool isCloudSynced;
  final bool isSignedIn;
  final bool isCreating;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final localProgress = hasLocalBackup ? 1.0 : 0.0;
    final cloudProgress = isCloudSynced
        ? 1.0
        : (isSignedIn ? 0.5 : 0.0);

    final localColor =
        hasLocalBackup ? AppColors.payment : AppColors.warning;
    final cloudColor = isCloudSynced
        ? AppColors.payment
        : (isSignedIn ? AppColors.warning : inkMuted);

    final bothSafe = hasLocalBackup && isCloudSynced;
    final centerLabel = bothSafe
        ? '✓'
        : (hasLocalBackup ? '◐' : '!');
    final centerColor = bothSafe
        ? AppColors.payment
        : (hasLocalBackup ? AppColors.warning : AppColors.warning);

    final statusTitle = hasLocalBackup
        ? (bothSafe
            ? l10n.backupStatusSafe
            : l10n.backupStatusLocalOnly)
        : l10n.backupStatusNoBackup;

    final statusSubtitle = hasLocalBackup && lastBackup != null
        ? '${l10n.backupLastBackup}: ${formatBackupRelativeDate(l10n, lastBackup!.createdAt)}'
        : l10n.backupStatusNoBackupSubtitle;

    return FadeSlideTransition(
      duration: AppDimensions.animationSlow,
      child: DaftarCard(
        variant: DaftarCardVariant.hero,
        padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: AppTextStyles.titleLarge.copyWith(
                          color: inkPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(AppDimensions.spacingXxs),
                      Text(
                        statusSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (backupCount > 0) ...[
                        const Gap(AppDimensions.spacingSm),
                        Text(
                          l10n.backupTotalSize(
                            backupCount,
                            formatBackupSize(l10n, totalSizeBytes),
                          ),
                          style: AppTextStyles.amountSmall.copyWith(
                            color: inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(AppDimensions.spacingMd),
                VaultHealthRings(
                  localProgress: localProgress,
                  cloudProgress: cloudProgress,
                  localColor: localColor,
                  cloudColor: cloudColor,
                  centerLabel: centerLabel,
                  centerColor: centerColor,
                  size: 88,
                  showLegend: true,
                  localLegend: l10n.backupHealthLocal,
                  cloudLegend: l10n.backupHealthCloud,
                ),
              ],
            ),
            const Gap(AppDimensions.spacingXl),
            DaftarButton(
              label: isCreating ? l10n.backupCreating : l10n.backupCreateNow,
              icon: Icons.backup_rounded,
              size: DaftarButtonSize.xlarge,
              isExpanded: true,
              isLoading: isCreating,
              onPressed: isCreating ? null : onCreateTap,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
  }
}
