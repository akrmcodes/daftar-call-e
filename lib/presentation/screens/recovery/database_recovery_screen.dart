import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/recovery/database_recovery_coordinator.dart';
import 'package:daftar/core/recovery/local_database_reset.dart';
import 'package:daftar/core/utils/app_restarter.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/localized_error_content.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_remote_tile.dart'
    show formatDriveBackupDate;
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Full-screen recovery vault when local SQLite integrity fails on startup.
class DatabaseRecoveryScreen extends StatefulWidget {
  const DatabaseRecoveryScreen({super.key});

  @override
  State<DatabaseRecoveryScreen> createState() => _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState extends State<DatabaseRecoveryScreen> {
  final DatabaseRecoveryCoordinator _coordinator =
      DatabaseRecoveryCoordinator();

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? AppColors.surface1 : AppColors.surface1Light;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final iconBackground = AppColors.warning.withValues(
      alpha: isDark ? 0.16 : 0.12,
    );

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.pagePaddingH,
            vertical: AppDimensions.pagePaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBackground,
                  ),
                  child: Icon(
                    Icons.restore_page_outlined,
                    size: 48,
                    color: isDark ? AppColors.warning : AppColors.warning,
                  ),
                ),
              ),
              const Gap(AppDimensions.spacingXl),
              Text(
                l10n.recoveryTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  color: inkPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppDimensions.spacingMd),
              Text(
                l10n.recoveryBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: inkSecondary),
              ),
              const Spacer(flex: 3),
              DaftarButton(
                label: l10n.recoveryRestoreDrive,
                icon: Icons.cloud_download_rounded,
                isExpanded: true,
                isLoading: _isBusy,
                onPressed: _isBusy ? null : _restoreFromGoogleDrive,
              ),
              const Gap(AppDimensions.spacingMd),
              DaftarButton(
                label: l10n.recoveryRestoreFromFile,
                icon: Icons.upload_file_rounded,
                variant: DaftarButtonVariant.secondary,
                isExpanded: true,
                isLoading: _isBusy,
                onPressed: _isBusy ? null : _restoreFromLocalFile,
              ),
              const Gap(AppDimensions.spacingMd),
              TextButton(
                onPressed: _isBusy ? null : _confirmFactoryReset,
                child: Text(
                  l10n.recoveryStartFresh,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.debt,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Gap(AppDimensions.spacingSm),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreFromGoogleDrive() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    unawaited(HapticService.buttonPress());

    try {
      final listResult = await _coordinator.listDriveBackups();
      if (!mounted) {
        return;
      }

      final backups = listResult.fold(
        (failure) {
          unawaited(_showFailure(failure));
          return <GoogleDriveRemoteBackupItem>[];
        },
        (items) => items,
      );

      if (backups.isEmpty) {
        if (listResult.isRight()) {
          unawaited(_showMessage(l10n.recoveryNoDriveBackups));
        }
        return;
      }

      backups.sort((a, b) {
        final aTime =
            a.modifiedTimeUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.modifiedTimeUtc ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      final selected = backups.length == 1
          ? backups.first
          : await _pickBackup(context, backups);

      if (!mounted || selected == null) {
        return;
      }

      final restoreResult = await _coordinator.restoreFromDrive(selected.id);
      if (!mounted) {
        return;
      }

      restoreResult.fold(
        (failure) => unawaited(_showFailure(failure)),
        (_) async {
          unawaited(HapticService.transactionSaved());
          await AppRestarter.restart();
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<GoogleDriveRemoteBackupItem?> _pickBackup(
    BuildContext context,
    List<GoogleDriveRemoteBackupItem> backups,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppColors.surface2 : AppColors.surface1Light;

    return showModalBottomSheet<GoogleDriveRemoteBackupItem>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppDimensions.spacingLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  child: Text(
                    l10n.recoveryPickBackupTitle,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    itemBuilder: (_, i) {
                      final item = backups[i];
                      final inkSecondary = isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight;
                      return InkWell(
                        onTap: () => Navigator.of(ctx).pop(item),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppDimensions.spacingLg,
                            vertical: AppDimensions.spacingMd,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cloud_done_rounded,
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
                                        formatDriveBackupDate(ctx, item),
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.inkPrimary
                                              : AppColors.inkPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item.sizeBytes != null
                                          ? formatBackupSize(
                                              l10n,
                                              item.sizeBytes!,
                                            )
                                          : '—',
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
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreFromLocalFile() async {
    setState(() => _isBusy = true);
    unawaited(HapticService.buttonPress());

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['daftar'],
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) return;

      final validation = _coordinator.validateBackupFile(path);
      if (!mounted) return;

      final file = validation.fold(
        (failure) {
          unawaited(_showFailure(failure));
          return null;
        },
        (file) => file,
      );
      if (file == null) return;

      final restoreResult = await _coordinator.restoreFromLocalFile(file.path);
      if (!mounted) return;

      restoreResult.fold(
        (failure) => unawaited(_showFailure(failure)),
        (_) async {
          unawaited(HapticService.transactionSaved());
          await AppRestarter.restart();
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _confirmFactoryReset() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.recoveryStartFreshConfirmTitle),
          content: Text(l10n.recoveryStartFreshConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.backupRestoreCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.recoveryStartFresh,
                style: const TextStyle(color: AppColors.debt),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    unawaited(HapticService.deleteConfirmed());
    try {
      await LocalDatabaseReset.executeAndRestart();
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _showFailure(Failure failure) async {
    if (!mounted) {
      return;
    }
    final content =
        ErrorTranslator.translate(AppLocalizations.of(context)!, failure);
    await DaftarErrorSheet.show(context, content: content);
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await DaftarErrorSheet.show(
      context,
      content: LocalizedErrorContent(
        title: l10n.recoveryTitle,
        message: message,
      ),
    );
  }
}
