import 'dart:async';
import 'dart:io';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_ambient_mesh.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_confirm_sheets.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_format_utils.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_history_section.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_restore_ceremony_overlay.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_vault_hero.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/drive_backup_section.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:daftar/presentation/shared/widgets/daftar_sliver_refresh.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleDriveListIfLinked(),
    );
  }

  void _scheduleDriveListIfLinked() {
    if (!mounted) {
      return;
    }
    final session = ref.read(authStateProvider).asData?.value;
    if (session == AuthSessionState.linked) {
      ref.read(driveBackupProvider.notifier).scheduleRemoteListLoad();
    }
  }

  Future<void> _createBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.medium();
    if (!context.mounted) return;

    final ok = await BackupVaultCeremonyOverlay.runWithCeremony(
      context: context,
      mode: VaultCeremonyMode.create,
      successTitle: l10n.backupSuccess,
      successSubtitle: l10n.backupCreateSuccessBody,
      operation: () => ref.read(backupProvider.notifier).createBackup(),
    );

    if (!context.mounted) return;
    if (!ok) {
      final failure =
          ref.read(backupProvider).lastFailure ??
          const ValidationFailure('', code: 'unknown');
      unawaited(AppBottomSheet.showError(context, error: failure));
    }
  }

  Future<void> _shareBackup(BuildContext context, BackupMetadata meta) async {
    final l10n = AppLocalizations.of(context)!;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(meta.filePath)],
        subject: l10n.backupShareSubject,
      ),
    );
  }

  Future<void> _deleteBackup(BuildContext context, BackupMetadata meta) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BackupDeleteConfirmSheet.show(context);
    if (!confirmed || !context.mounted) return;

    await HapticService.medium();
    final notifier = ref.read(backupProvider.notifier);
    final ok = await notifier.deleteBackup(meta.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.backupDeleteSuccess : l10n.backupDeleteFailed),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndRestore(
    BuildContext context,
    BackupMetadata? knownMeta,
    File file,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BackupRestoreConfirmSheet.show(context);
    if (!confirmed || !context.mounted) return;

    await HapticService.heavy();

    final checksum = knownMeta?.checksum ?? '';
    final notifier = ref.read(backupProvider.notifier);
    final cachedMetadata = List.of(ref.read(backupProvider).backups);

    if (!context.mounted) return;
    final ok = await BackupVaultCeremonyOverlay.runWithCeremony(
      context: context,
      mode: VaultCeremonyMode.restoreLocal,
      successTitle: l10n.backupRestoreSuccess,
      successSubtitle: l10n.backupRestoreSuccessBody,
      operation: () => notifier.restoreBackup(file, checksum),
    );

    if (!context.mounted) return;

    if (ok) {
      await notifier.softRestart(cachedMetadata);
      if (!context.mounted) return;
      context.goNamed(RouteNames.home);
    } else {
      final failure =
          ref.read(backupProvider).lastFailure ??
          const ValidationFailure('', code: 'unknown');
      unawaited(AppBottomSheet.showError(context, error: failure));
    }
  }

  Future<void> _restoreFromExternalFile(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['daftar'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || !context.mounted) return;
    await _confirmAndRestore(context, null, File(path));
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.light();
    final result = await ref
        .read(signInControllerProvider.notifier)
        .signInWithGoogle();
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorTranslator.signInFailureMessage(l10n, failure)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) async {
        ref.read(backupSyncStatusProvider.notifier).clearNeedsReauthHint();
        unawaited(ref.read(driveBackupProvider.notifier).refreshRemoteList());
        final settings = await ref.read(settingsRepositoryProvider).get();
        await settings.fold(
          (_) async {},
          AutoBackupScheduler.ensureScheduled,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.backupDriveSignInSuccess),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Future<void> _signOutGoogle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.light();
    final result = await ref.read(signInControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.backupDriveSignOutFailed),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.backupDriveSignOutSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  Future<void> _uploadToDrive(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.medium();
    final ok = await ref.read(driveBackupProvider.notifier).uploadToDrive();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.backupDriveUploadSuccess : l10n.backupDriveUploadFailed,
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreFromDrive(
    BuildContext context,
    GoogleDriveRemoteBackupItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BackupRestoreConfirmSheet.show(context);
    if (!confirmed || !context.mounted) return;

    await HapticService.heavy();
    final cachedMetadata = List.of(ref.read(backupProvider).backups);

    if (!context.mounted) return;
    final ok = await BackupVaultCeremonyOverlay.runWithCeremony(
      context: context,
      mode: VaultCeremonyMode.restoreDrive,
      successTitle: l10n.backupRestoreSuccess,
      successSubtitle: l10n.backupRestoreSuccessBody,
      operation: () =>
          ref.read(driveBackupProvider.notifier).restoreFromDrive(item.id),
    );

    if (!context.mounted) return;

    if (ok) {
      await ref.read(backupProvider.notifier).softRestart(cachedMetadata);
      if (!context.mounted) return;
      context.goNamed(RouteNames.home);
    } else {
      final failure = ref.read(driveBackupProvider).lastFailure;
      final err = failure != null
          ? ErrorTranslator.driveFailureMessage(l10n, failure)
          : l10n.backupRestoreFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDriveBackup(
    BuildContext context,
    GoogleDriveRemoteBackupItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await BackupDriveDeleteConfirmSheet.show(context);
    if (!confirmed || !context.mounted) return;

    await HapticService.medium();
    final ok = await ref
        .read(driveBackupProvider.notifier)
        .deleteRemote(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.backupDriveDeleteRemoteSuccess
              : l10n.backupDriveDeleteRemoteFailed,
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;

    final state = ref.watch(backupProvider);
    final driveState = ref.watch(driveBackupProvider);
    final authAsync = ref.watch(authStateProvider);

    ref
      ..listen(authStateProvider, (prev, next) {
        final prevSession = prev?.asData?.value;
        final nextSession = next.asData?.value;
        if (nextSession == AuthSessionState.linked &&
            prevSession != AuthSessionState.linked) {
          ref.read(driveBackupProvider.notifier).scheduleRemoteListLoad();
          return;
        }
        if (prevSession == AuthSessionState.linked &&
            nextSession != AuthSessionState.linked) {
          ref.invalidate(driveBackupProvider);
        }
      })
      ..listen(googleAccountProvider, (prev, next) {
        final prevId = prev?.asData?.value?.id;
        final nextId = next.asData?.value?.id;
        if (nextId != null &&
            prevId != null &&
            nextId != prevId &&
            ref.read(authStateProvider).asData?.value ==
                AuthSessionState.linked) {
          unawaited(
            ref.read(driveBackupProvider.notifier).refreshRemoteList(),
          );
        }
      });

    final lastBackup = state.backups.isNotEmpty ? state.backups.first : null;
    final hasLocalBackup = state.backups.isNotEmpty;
    final isSignedIn =
        authAsync.asData?.value == AuthSessionState.linked;
    final driveFileId = lastBackup?.googleDriveFileId;
    final hasLocalDriveLink =
        driveFileId != null && driveFileId.isNotEmpty;
    final hasCloudBackup = hasLocalDriveLink ||
        (isSignedIn && driveState.remoteBackups.isNotEmpty);
    final isCloudSynced = hasLocalBackup && hasCloudBackup;
    final totalSize = sumBackupBytes(state.backups.map((b) => b.sizeBytes));
    final bottomScrollClearance = MediaQuery.paddingOf(context).bottom +
        AppDimensions.shellDockScrollInset;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surface0 : AppColors.surface0Light,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BackupAmbientMesh(),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              DaftarSliverRefreshControl(
                onRefresh: () => daftarRefreshWithPerceivedDelay(() async {
                  await ref.read(backupProvider.notifier).refresh();
                  if (ref.read(authStateProvider).asData?.value ==
                      AuthSessionState.linked) {
                    await ref
                        .read(driveBackupProvider.notifier)
                        .refreshRemoteList();
                  }
                }),
              ),
              DaftarScrollScreenTitleSliver(
                title: Text(
                  l10n.backupTitle,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: BackupVaultHero(
                    lastBackup: lastBackup,
                    backupCount: state.backups.length,
                    totalSizeBytes: totalSize,
                    hasLocalBackup: hasLocalBackup,
                    isCloudSynced: isCloudSynced,
                    isSignedIn: isSignedIn,
                    isCreating: state.isCreating,
                    onCreateTap: () => _createBackup(context),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Gap(AppDimensions.spacingXxl),
              ),
              SliverToBoxAdapter(
                child: BackupHistorySection(
                  backups: state.backups,
                  isLoading: state.isLoading,
                  isRestoring: state.isRestoring,
                  onShare: (meta) => _shareBackup(context, meta),
                  onRestore: (meta) => _confirmAndRestore(
                    context,
                    meta,
                    File(meta.filePath),
                  ),
                  onDelete: (meta) => _deleteBackup(context, meta),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
                  child: DaftarButton(
                    label: l10n.backupRestoreFromFile,
                    icon: Icons.upload_file_rounded,
                    variant: DaftarButtonVariant.secondary,
                    size: DaftarButtonSize.large,
                    isExpanded: true,
                    onPressed: state.isRestoring
                        ? null
                        : () => _restoreFromExternalFile(context),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Gap(AppDimensions.spacingXxl),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: DriveBackupSection(
                    onSignIn: () => _signInWithGoogle(context),
                    onSignOut: () => _signOutGoogle(context),
                    onUpload: () => _uploadToDrive(context),
                    onRestore: (item) => _restoreFromDrive(context, item),
                    onDelete: (item) => _deleteDriveBackup(context, item),
                    onRetryQueue: () {
                      unawaited(
                        ref.read(driveBackupProvider.notifier).retryQueueNow(),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: bottomScrollClearance),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
