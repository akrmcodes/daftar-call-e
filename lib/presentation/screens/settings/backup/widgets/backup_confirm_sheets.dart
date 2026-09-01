import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Bottom-sheet confirmation before deleting a local backup.
class BackupDeleteConfirmSheet extends StatelessWidget {
  const BackupDeleteConfirmSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await AppBottomSheet.show<bool>(
      context,
      title: AppLocalizations.of(context)!.backupDeleteConfirmTitle,
      maxHeightFactor: 0.5,
      scrollable: false,
      child: const BackupDeleteConfirmSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.backupDeleteConfirmBody,
          style: AppTextStyles.bodyMedium.copyWith(
            color: inkSecondary,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppDimensions.spacingXl),
        DaftarButton(
          label: l10n.backupDelete,
          variant: DaftarButtonVariant.destructive,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.deleteConfirmed());
            Navigator.of(context).pop(true);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.backupRestoreCancel,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Bottom-sheet warning before destructive restore.
class BackupRestoreConfirmSheet extends StatelessWidget {
  const BackupRestoreConfirmSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await AppBottomSheet.show<bool>(
      context,
      title: AppLocalizations.of(context)!.backupRestoreWarningTitle,
      maxHeightFactor: 0.55,
      scrollable: false,
      child: const BackupRestoreConfirmSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    const warningColor = AppColors.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: warningColor,
              size: AppDimensions.iconMedium + 4,
            ),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                l10n.backupRestoreWarningBody,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingXl),
        DaftarButton(
          label: l10n.backupRestoreConfirm,
          variant: DaftarButtonVariant.destructive,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.heavy());
            Navigator.of(context).pop(true);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.backupRestoreCancel,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

/// Bottom-sheet confirmation before deleting a remote Drive backup.
class BackupDriveDeleteConfirmSheet extends StatelessWidget {
  const BackupDriveDeleteConfirmSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await AppBottomSheet.show<bool>(
      context,
      title: AppLocalizations.of(context)!.backupDriveDeleteRemoteTitle,
      maxHeightFactor: 0.5,
      scrollable: false,
      child: const BackupDriveDeleteConfirmSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.backupDriveDeleteRemoteBody,
          style: AppTextStyles.bodyMedium.copyWith(
            color: inkSecondary,
            height: 1.45,
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(AppDimensions.spacingXl),
        DaftarButton(
          label: l10n.backupDelete,
          variant: DaftarButtonVariant.destructive,
          size: DaftarButtonSize.large,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.deleteConfirmed());
            Navigator.of(context).pop(true);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.backupRestoreCancel,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
