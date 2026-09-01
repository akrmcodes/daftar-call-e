import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/auto_backup/auto_backup_battery_gate.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/domain/constants/drive_backup_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/drive_auto_backup_interval.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_google_button.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_session_banner.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_relative_date.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_action_grid.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_remote_tile.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_restore_picker_sheet.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_status_banners.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:permission_handler/permission_handler.dart';

/// Google Drive backup section — auth, auto-backup, upload/restore, cloud list.
class DriveBackupSection extends ConsumerWidget {
  const DriveBackupSection({
    required this.onSignIn,
    required this.onSignOut,
    required this.onUpload,
    required this.onRestore,
    required this.onDelete,
    required this.onRetryQueue,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final VoidCallback onUpload;
  final void Function(GoogleDriveRemoteBackupItem item) onRestore;
  final void Function(GoogleDriveRemoteBackupItem item) onDelete;
  final VoidCallback onRetryQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    final authAsync = ref.watch(authStateProvider);
    final accountAsync = ref.watch(googleAccountProvider);
    final driveState = ref.watch(driveBackupProvider);
    final syncView = ref.watch(backupSyncStatusProvider);
    final signInBusy = ref.watch(signInControllerProvider).isLoading;
    final grantBusy = ref.watch(driveOfflineGrantControllerProvider).isLoading;
    final settingsAsync = ref.watch(appSettingsProvider);
    final session = authAsync.asData?.value;
    final grantReady =
        ref.watch(driveOfflineGrantReadyProvider).asData?.value ?? false;

    Future<void> handleSignIn() async => onSignIn();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.backupDriveSectionTitle,
          style: AppTextStyles.titleMedium.copyWith(
            color: inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        DriveStatusBanners(
          l10n: l10n,
          syncView: syncView,
          isTransferring: driveState.isTransferring,
          onSignIn: onSignIn,
          onRetryQueue: onRetryQueue,
        ),
        if (session == AuthSessionState.linked && !grantReady) ...[
          const Gap(AppDimensions.spacingSm),
          DriveBanner(
            background: AppColors.warning.withValues(alpha: 0.12),
            border: AppColors.warning.withValues(alpha: 0.35),
            icon: Icons.key_rounded,
            iconColor: AppColors.warning,
            message: l10n.backupDriveOfflineGrantMissing,
            actionLabel: l10n.backupDriveOfflineGrantAction,
            onAction: grantBusy
                ? null
                : () => unawaited(_completeDriveAuthorization(context, ref)),
            actionLoading: grantBusy,
            inkPrimary:
                isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          ),
        ],
        if (session == AuthSessionState.migrationRelinkRequired) ...[
          const Gap(AppDimensions.spacingMd),
          AccountMigrationRelinkBanner(
            isDark: isDark,
            isLoading: signInBusy,
            ghostEmail: settingsAsync.asData?.value.googleAccountEmail,
            onSignIn: handleSignIn,
          ),
        ] else if (session == AuthSessionState.needsReauth) ...[
          const Gap(AppDimensions.spacingMd),
          AccountNeedsReauthBanner(
            isDark: isDark,
            isLoading: signInBusy,
            onSignIn: handleSignIn,
          ),
        ],
        const Gap(AppDimensions.spacingMd),
        DaftarCard(
          child: authAsync.when(
            loading: () => const DriveSectionSkeleton(),
            error: (_, _) => DriveInviteCard(
              l10n: l10n,
              isDark: isDark,
              onSignIn: onSignIn,
              isLoading: signInBusy,
            ),
            data: (session) {
              if (session == AuthSessionState.migrationRelinkRequired ||
                  session == AuthSessionState.needsReauth) {
                return DriveRecoveryPlaceholder(l10n: l10n, isDark: isDark);
              }
              if (session != AuthSessionState.linked) {
                return DriveInviteCard(
                  l10n: l10n,
                  isDark: isDark,
                  onSignIn: onSignIn,
                  isLoading: signInBusy,
                );
              }

              if (driveState.isTransferring) {
                return DriveTransferProgress(
                  l10n: l10n,
                  state: driveState,
                  onCancel: () =>
                      ref.read(driveBackupProvider.notifier).cancelTransfer(),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  accountAsync.when(
                    loading: () => const DriveAccountHeaderSkeleton(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (profile) => DriveAccountHeader(profile: profile),
                  ),
                  const Gap(AppDimensions.spacingLg),
                  settingsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (settings) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DriveAutoBackupControls(
                          l10n: l10n,
                          settings: settings,
                          grantReady: grantReady,
                          onChanged: ({required enabled, required interval}) =>
                              unawaited(
                            _persistAutoBackup(
                              ref,
                              context: context,
                              enabled: enabled,
                              interval: interval,
                              grantReady: grantReady,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppDimensions.spacingLg),
                  DriveActionGrid(
                    l10n: l10n,
                    onUpload: onUpload,
                    onRestoreList: driveState.remoteBackups.isEmpty
                        ? null
                        : () => unawaited(
                              DriveRestorePickerSheet.show(
                                context,
                                ref: ref,
                                onSelected: onRestore,
                              ),
                            ),
                  ),
                  const Gap(AppDimensions.spacingXl),
                  Text(
                    l10n.backupDriveCloudBackups,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppDimensions.spacingSm),
                  if (driveState.isLoadingList)
                    const DriveListSkeleton()
                  else if (driveState.remoteBackups.isEmpty)
                    DriveEmptyCloudList(l10n: l10n)
                  else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _previewBackups(driveState.remoteBackups).length,
                      findChildIndexCallback: (key) {
                        if (key is ValueKey<String>) {
                          final preview = _previewBackups(
                            driveState.remoteBackups,
                          );
                          final index = preview.indexWhere(
                            (b) => b.id == key.value,
                          );
                          return index >= 0 ? index : null;
                        }
                        return null;
                      },
                      itemBuilder: (context, i) {
                        final preview = _previewBackups(
                          driveState.remoteBackups,
                        );
                        final item = preview[i];
                        return DriveRemoteTile(
                          key: ValueKey(item.id),
                          item: item,
                          l10n: l10n,
                          onRestore: () => onRestore(item),
                          onDelete: () => onDelete(item),
                        )
                            .animate()
                            .fadeIn(duration: 220.ms, delay: (i * 40).ms);
                      },
                    ),
                    if (driveState.remoteBackups.length >
                        DriveBackupConstants.cloudBackupsInlinePreviewLimit) ...[
                      const Gap(AppDimensions.spacingSm),
                      Text(
                        l10n.backupDriveCloudBackupsPreviewFootnote(
                          DriveBackupConstants.cloudBackupsInlinePreviewLimit,
                          driveState.remoteBackups.length,
                        ),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                  const Gap(AppDimensions.spacingLg),
                  DaftarButton(
                    label: l10n.backupDriveSignOut,
                    variant: DaftarButtonVariant.tertiary,
                    isExpanded: true,
                    onPressed: signInBusy ? null : onSignOut,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04, end: 0);
  }

  static List<GoogleDriveRemoteBackupItem> _previewBackups(
    List<GoogleDriveRemoteBackupItem> backups,
  ) {
    const limit = DriveBackupConstants.cloudBackupsInlinePreviewLimit;
    if (backups.length <= limit) {
      return backups;
    }
    return backups.sublist(0, limit);
  }

  static Future<void> _completeDriveAuthorization(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await ref
          .read(driveOfflineGrantControllerProvider.notifier)
          .completeDriveAuthorization();
      if (!context.mounted) return;
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ErrorTranslator.driveFailureMessage(l10n, failure),
              ),
            ),
          );
        },
        (_) {},
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is Failure
                ? ErrorTranslator.driveFailureMessage(l10n, error)
                : l10n.backupDriveOfflineGrantFailed,
          ),
        ),
      );
    }
  }

  static Future<void> _persistAutoBackup(
    WidgetRef ref, {
    required BuildContext context,
    required bool enabled,
    required DriveAutoBackupInterval interval,
    required bool grantReady,
  }) async {
    if (enabled && !grantReady) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDriveOfflineGrantMissing)),
        );
      }
      return;
    }

    if (enabled) {
      final granted =
          await ref.read(notificationServiceProvider).requestPermissions();
      if (!granted && context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.backupDriveNotificationPermissionDenied),
            action: SnackBarAction(
              label: l10n.backupDriveNotificationPermissionOpenSettings,
              onPressed: () {
                unawaited(openAppSettings());
              },
            ),
          ),
        );
        unawaited(openAppSettings());
      }
    }

    final repo = ref.read(settingsRepositoryProvider);
    final result = await repo.update(
      UpdateSettingsParams(
        driveAutoBackupEnabled: enabled,
        driveAutoBackupInterval: interval.storageValue,
      ),
    );
    await result.fold(
      (_) async {},
      (settings) async {
        await AutoBackupScheduler.applyFromSettings(settings);
      },
    );

    if (enabled && context.mounted) {
      await _promptBatteryOptimizationIfNeeded(context);
    }
  }

  static Future<void> _promptBatteryOptimizationIfNeeded(
    BuildContext context,
  ) async {
    if (!await AutoBackupBatteryGate.shouldPrompt()) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          isDark ? AppColors.surface2 : AppColors.surface0Light,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.spacingLg,
              AppDimensions.spacingLg,
              AppDimensions.spacingLg,
              AppDimensions.spacingXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.backupDriveBatteryOptTitle,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(AppDimensions.spacingMd),
                Text(
                  l10n.backupDriveBatteryOptBody,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: inkSecondary,
                    height: 1.45,
                  ),
                ),
                const Gap(AppDimensions.spacingLg),
                DaftarButton(
                  label: l10n.backupDriveBatteryOptAllow,
                  onPressed: () async {
                    await AutoBackupBatteryGate.markPromptShown();
                    await AutoBackupBatteryGate.requestUnrestrictedBattery();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
                const Gap(AppDimensions.spacingSm),
                TextButton(
                  onPressed: () async {
                    await AutoBackupBatteryGate.markPromptShown();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Text(l10n.backupDriveBatteryOptLater),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DriveInviteCard extends StatelessWidget {
  const DriveInviteCard({
    required this.l10n,
    required this.isDark,
    required this.onSignIn,
    required this.isLoading,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onSignIn;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 52,
          color: inkSecondary,
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.backupDriveInviteBody,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            height: 1.5,
            color: inkSecondary,
          ),
        ),
        const Gap(AppDimensions.spacingXl),
        AccountGoogleButton(
          label: l10n.backupDriveSignInWithGoogle,
          isDark: isDark,
          isLoading: isLoading,
          onPressed: isLoading ? null : onSignIn,
          variant: AccountGoogleButtonVariant.primary,
        ),
      ],
    );
  }
}

/// Placeholder when session recovery banner above handles sign-in.
class DriveRecoveryPlaceholder extends StatelessWidget {
  const DriveRecoveryPlaceholder({
    required this.l10n,
    required this.isDark,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Column(
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 52,
          color: inkSecondary,
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.backupDriveInviteBody,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge.copyWith(
            height: 1.5,
            color: inkSecondary,
          ),
        ),
      ],
    );
  }
}

class DriveAccountHeader extends StatelessWidget {
  const DriveAccountHeader({required this.profile, super.key});

  final GoogleAccountProfile? profile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    final email = profile?.email ?? '';
    final name = profile?.displayName;
    final photo = profile?.photoUrl;

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 0.5),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor:
                isDark ? AppColors.surface4 : AppColors.surface2Light,
            backgroundImage:
                photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo == null || photo.isEmpty
                ? Text(
                    email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: inkPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
        const Gap(AppDimensions.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name != null && name.isNotEmpty)
                Text(
                  name,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              Text(
                email,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DriveAutoBackupControls extends StatelessWidget {
  const DriveAutoBackupControls({
    required this.l10n,
    required this.settings,
    required this.grantReady,
    required this.onChanged,
    super.key,
  });

  final AppLocalizations l10n;
  final AppSettings settings;
  final bool grantReady;
  final void Function({
    required bool enabled,
    required DriveAutoBackupInterval interval,
  }) onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final fill = isDark ? AppColors.surface4 : AppColors.surface2Light;
    final border = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    final interval = DriveAutoBackupInterval.fromStorage(
      settings.driveAutoBackupInterval,
    );
    // Allow turning off even without grant; block turning on until PKCE ready.
    final canEnable = grantReady || settings.driveAutoBackupEnabled;

    // Material (not DecoratedBox) so SwitchListTile ink/splash stay visible —
    // DecoratedBox between ListTile and Material throws a fatal FlutterError.
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        side: BorderSide(color: border, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm,
        ),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.backupDriveAutoBackupLabel,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: inkPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: settings.driveAutoBackupEnabled,
              onChanged: canEnable
                  ? (enabled) =>
                      onChanged(enabled: enabled, interval: interval)
                  : null,
            ),
            if (settings.driveAutoBackupEnabled) ...[
              Divider(
                height: 1,
                color: border,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.spacingMd,
                  end: AppDimensions.spacingMd,
                  top: AppDimensions.spacingXs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    settings.lastBackupAt == null
                        ? l10n.backupDriveAutoBackupNeverRun
                        : l10n.backupDriveAutoBackupLastRun(
                            formatBackupRelativeDate(
                              l10n,
                              settings.lastBackupAt!,
                            ),
                          ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: inkSecondary,
                    ),
                  ),
                ),
              ),
              if (Platform.isIOS)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.spacingMd,
                    end: AppDimensions.spacingMd,
                    top: AppDimensions.spacingXs,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.backupDriveAutoBackupIosHint,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkSecondary,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.spacingMd,
                  end: AppDimensions.spacingMd,
                  top: AppDimensions.spacingXs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.backupDriveTimingHonesty,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: inkSecondary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: AppDimensions.spacingXs,
                  end: AppDimensions.spacingXs,
                  bottom: AppDimensions.spacingXs,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: inkSecondary,
                    ),
                    const Gap(AppDimensions.spacingMd),
                    Expanded(
                      child: Text(
                        l10n.backupDriveAutoBackupInterval,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: inkPrimary,
                        ),
                      ),
                    ),
                    DropdownButton<DriveAutoBackupInterval>(
                      value: interval,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: DriveAutoBackupInterval.daily,
                          child: Text(l10n.backupDriveAutoBackupDaily),
                        ),
                        DropdownMenuItem(
                          value: DriveAutoBackupInterval.weekly,
                          child: Text(l10n.backupDriveAutoBackupWeekly),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          onChanged(enabled: true, interval: value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DriveTransferProgress extends StatelessWidget {
  const DriveTransferProgress({
    required this.l10n,
    required this.state,
    required this.onCancel,
    super.key,
  });

  final AppLocalizations l10n;
  final DriveBackupState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final trackColor = isDark ? AppColors.surface5 : AppColors.surface3Light;

    final percent = (state.progress * 100).round().clamp(0, 100);
    final label = state.transferKind == DriveTransferKind.upload
        ? l10n.backupDriveUploading
        : l10n.backupDriveDownloading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTextStyles.titleSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: state.progress),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      backgroundColor: trackColor,
                      color: AppColors.lapis400,
                    );
                  },
                ),
              ),
            ),
            const Gap(AppDimensions.spacingSm),
            Text(
              l10n.backupDrivePercent(percent),
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.lapis400,
                height: 1,
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingLg),
        Align(
          alignment: AlignmentDirectional.center,
          child: TextButton(
            onPressed: onCancel,
            child: Text(
              l10n.backupDriveCancel,
              style: AppTextStyles.labelLarge.copyWith(
                color: inkSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
