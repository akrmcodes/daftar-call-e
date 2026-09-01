import 'dart:async';
import 'dart:io';

import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/application/backup/backup_queue_process_report.dart';
import 'package:daftar/application/backup/create_local_backup_use_case.dart';
import 'package:daftar/application/backup/delete_drive_backup_use_case.dart';
import 'package:daftar/application/backup/download_drive_backup_use_case.dart';
import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/application/backup/process_backup_queue_use_case.dart';
import 'package:daftar/application/backup/restore_backup_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/connectivity_service.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/mappers/backup_metadata_mapper.dart';
import 'package:daftar/data/repositories/backup_queue_repository_impl.dart';
import 'package:daftar/data/repositories/backup_repository_impl.dart';
import 'package:daftar/data/repositories/google_drive_backup_remote_repository_impl.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/domain/enums/auto_backup_notification_event.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:daftar/main.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/connectivity_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/storage_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_providers.g.dart';

/// Provides the [BackupRepository] implementation.
@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) {
  return BackupRepositoryImpl(
    backupLocalDs: ref.watch(backupLocalDsProvider),
  );
}

/// Provides the [CreateLocalBackupUseCase].
@Riverpod(keepAlive: true)
CreateLocalBackupUseCase createLocalBackupUseCase(Ref ref) {
  return CreateLocalBackupUseCase(
    ref.watch(backupRepositoryProvider),
    ref.watch(storageServiceProvider),
  );
}

/// Provides the [RestoreBackupUseCase].
@Riverpod(keepAlive: true)
RestoreBackupUseCase restoreBackupUseCase(Ref ref) {
  return RestoreBackupUseCase(
    ref.watch(backupRepositoryProvider),
    ref.watch(storageServiceProvider),
  );
}

/// Provides authenticated Google Drive backup API access.
@Riverpod(keepAlive: true)
GoogleDriveBackupRemoteRepository googleDriveBackupRemoteRepository(Ref ref) {
  return GoogleDriveBackupRemoteRepositoryImpl(
    googleAuthDs: ref.watch(googleAuthDsProvider),
  );
}

/// Provides the [UploadDriveBackupUseCase].
@Riverpod(keepAlive: true)
UploadDriveBackupUseCase uploadDriveBackupUseCase(Ref ref) {
  return UploadDriveBackupUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    backupRepository: ref.watch(backupRepositoryProvider),
    driveRemoteRepository: ref.watch(googleDriveBackupRemoteRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
    enqueueDriveBackupUploadUseCase:
        ref.watch(enqueueDriveBackupUploadUseCaseProvider),
  );
}

/// Provides the [DownloadDriveBackupUseCase].
@Riverpod(keepAlive: true)
DownloadDriveBackupUseCase downloadDriveBackupUseCase(Ref ref) {
  return DownloadDriveBackupUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    driveRemoteRepository: ref.watch(googleDriveBackupRemoteRepositoryProvider),
    restoreBackupUseCase: ref.watch(restoreBackupUseCaseProvider),
  );
}

/// Provides the [DeleteDriveBackupUseCase].
@Riverpod(keepAlive: true)
DeleteDriveBackupUseCase deleteDriveBackupUseCase(Ref ref) {
  return DeleteDriveBackupUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    driveRemoteRepository: ref.watch(googleDriveBackupRemoteRepositoryProvider),
  );
}

/// Provides the [BackupQueueRepository] implementation.
@Riverpod(keepAlive: true)
BackupQueueRepository backupQueueRepository(Ref ref) {
  return BackupQueueRepositoryImpl(
    localDs: ref.watch(backupQueueLocalDsProvider),
  );
}

/// Provides the [EnqueueDriveBackupUploadUseCase].
@Riverpod(keepAlive: true)
EnqueueDriveBackupUploadUseCase enqueueDriveBackupUploadUseCase(Ref ref) {
  return EnqueueDriveBackupUploadUseCase(
    ref.watch(backupQueueRepositoryProvider),
  );
}

/// Provides the [ProcessBackupQueueUseCase].
@Riverpod(keepAlive: true)
ProcessBackupQueueUseCase processBackupQueueUseCase(Ref ref) {
  return ProcessBackupQueueUseCase(
    authRepository: ref.watch(authRepositoryProvider),
    backupQueueRepository: ref.watch(backupQueueRepositoryProvider),
    uploadDriveBackupUseCase: ref.watch(uploadDriveBackupUseCaseProvider),
  );
}

/// Surface state for non-blocking Drive backup / sync UI hints.
enum BackupSyncSurfaceState {
  synced,
  syncing,
  offline,
  quotaExceeded,
  needsReauth,
}

/// Combined Drive sync view: primary [surface] plus optional retry hint.
@immutable
class BackupSyncStatusView {
  /// Creates a view with the given [surface] and optional retry hint.
  const BackupSyncStatusView({
    required this.surface,
    this.driveRetryScheduled = false,
  });

  /// Primary phase for banners / icons.
  final BackupSyncSurfaceState surface;

  /// True when a transient network error was classified and backoff retry
  /// was scheduled (UI may show "will resume when online").
  final bool driveRetryScheduled;
}

/// Exposes Drive-related sync hints without blocking offline use.
@Riverpod(keepAlive: true)
class BackupSyncStatus extends _$BackupSyncStatus {
  bool _offline = false;
  bool _needsReauth = false;
  bool _quotaExceeded = false;
  bool _foregroundDriveBusy = false;
  bool _driveRetryScheduled = false;
  bool _pendingCloudSync = false;
  AuthSessionState? _session;

  @override
  BackupSyncStatusView build() {
    ref
      ..listen(connectivityStatusProvider, _onConnectivityChanged)
      ..watch(connectivityStatusProvider)
      ..listen(authStateProvider, _onAuthSessionChanged);
    _session = ref.read(authStateProvider).asData?.value;
    unawaited(_bootstrap());
    return _computeView();
  }

  Future<void> _bootstrap() async {
    final status =
        await ref.read(connectivityServiceProvider).currentStatus();
    if (!ref.mounted) {
      return;
    }
    _offline = status == ConnectivityStatus.offline;

    final needs = await ref
        .read(backupQueueRepositoryProvider)
        .anyNeedsReauth();
    if (!ref.mounted) {
      return;
    }
    if (needs) {
      _needsReauth = true;
    }

    final settingsResult = await ref.read(settingsRepositoryProvider).get();
    if (!ref.mounted) {
      return;
    }
    settingsResult.fold((_) {}, (settings) {
      final failureCode = settings.lastAutoBackupFailureCode;
      if (failureCode == 'needs_reauth' ||
          failureCode == kDriveScopesNotAuthorizedCode ||
          failureCode == 'google_not_signed_in' ||
          failureCode == 'silent_sign_in_failed') {
        _needsReauth = true;
      }
      if (failureCode == 'storage_quota_exceeded') {
        _quotaExceeded = true;
      }
    });

    await refreshPendingCloudFlag();
    if (!ref.mounted) {
      return;
    }
    state = _computeView();
  }

  void _onConnectivityChanged(
    AsyncValue<ConnectivityStatus>? previous,
    AsyncValue<ConnectivityStatus> next,
  ) {
    if (next case AsyncData(value: final status)) {
      _offline = status == ConnectivityStatus.offline;
      state = _computeView();
    }
  }

  void _onAuthSessionChanged(
    AsyncValue<AuthSessionState>? previous,
    AsyncValue<AuthSessionState> next,
  ) {
    if (next case AsyncData(value: final session)) {
      _session = session;
      state = _computeView();
    }
  }

  BackupSyncStatusView _computeView() {
    BackupSyncSurfaceState surface;
    if (_offline) {
      surface = BackupSyncSurfaceState.offline;
    } else if ((_needsReauth || _session == AuthSessionState.needsReauth) &&
        _session != null &&
        _session != AuthSessionState.linked) {
      surface = BackupSyncSurfaceState.needsReauth;
    } else if (_quotaExceeded) {
      surface = BackupSyncSurfaceState.quotaExceeded;
    } else if (_foregroundDriveBusy ||
        _pendingCloudSync ||
        _driveRetryScheduled) {
      surface = BackupSyncSurfaceState.syncing;
    } else {
      surface = BackupSyncSurfaceState.synced;
    }
    return BackupSyncStatusView(
      surface: surface,
      driveRetryScheduled: _driveRetryScheduled,
    );
  }

  /// Re-reads the SharedPreferences flag and Drift queue for UI state.
  Future<void> refreshPendingCloudFlag() async {
    final fromPrefs = await PendingCloudSyncStore.hasPending();
    if (!ref.mounted) {
      return;
    }
    final queue = await ref.read(backupQueueRepositoryProvider).getPendingRetryable();
    if (!ref.mounted) {
      return;
    }
    _pendingCloudSync = fromPrefs || queue.isNotEmpty;
    state = _computeView();
  }

  /// Updates sticky flags after a queue processor pass.
  void applyQueueProcessReport(BackupQueueProcessReport report) {
    if (report.sawNeedsReauth) {
      _needsReauth = true;
    }
    if (report.sawQuotaExceeded) {
      _quotaExceeded = true;
    }
    if (report.sawTransientNetworkFailure) {
      _driveRetryScheduled = true;
      unawaited(PendingCloudSyncStore.setPending(value: true));
      _pendingCloudSync = true;
    }
    if (!report.sawTransientNetworkFailure &&
        !report.sawNeedsReauth &&
        !report.sawQuotaExceeded) {
      unawaited(refreshPendingCloudFlag());
    } else {
      state = _computeView();
    }
  }

  /// Marks foreground Drive work (upload/list) active for the syncing surface.
  void setForegroundDriveBusy({required bool busy}) {
    _foregroundDriveBusy = busy;
    state = _computeView();
  }

  /// Clears the transient "retry scheduled" hint (e.g. after user dismisses).
  void clearDriveRetryScheduledHint() {
    _driveRetryScheduled = false;
    state = _computeView();
  }

  /// Clears the sticky quota banner after the user frees Drive space.
  void clearQuotaExceededHint() {
    _quotaExceeded = false;
    state = _computeView();
  }

  /// Clears the needs-reauth hint after successful interactive sign-in.
  void clearNeedsReauthHint() {
    _needsReauth = false;
    state = _computeView();
  }
}

@Riverpod(keepAlive: true)
class DriveBackupHydrator extends _$DriveBackupHydrator {
  @override
  void build() {
    ref
      ..listen(authStateProvider, _onAuthSessionChanged)
      ..listen(googleAccountProvider, _onGoogleAccountChanged);
    unawaited(_primeRemoteListIfLinked());
  }

  Future<void> _primeRemoteListIfLinked() async {
    final session = await ref.read(authStateProvider.future);
    if (!ref.mounted || session != AuthSessionState.linked) {
      return;
    }
    await ref.read(driveBackupProvider.notifier).refreshRemoteList();
  }

  void _onAuthSessionChanged(
    AsyncValue<AuthSessionState>? previous,
    AsyncValue<AuthSessionState> next,
  ) {
    final previousSession = previous?.asData?.value;
    final nextSession = next.asData?.value;
    if (nextSession == AuthSessionState.linked &&
        previousSession != AuthSessionState.linked) {
      unawaited(ref.read(driveBackupProvider.notifier).refreshRemoteList());
    }
  }

  void _onGoogleAccountChanged(
    AsyncValue<GoogleAccountProfile?>? previous,
    AsyncValue<GoogleAccountProfile?> next,
  ) {
    final previousId = previous?.asData?.value?.id;
    final nextId = next.asData?.value?.id;
    if (nextId == null ||
        previousId == null ||
        nextId == previousId ||
        ref.read(authStateProvider).asData?.value != AuthSessionState.linked) {
      return;
    }
    unawaited(ref.read(driveBackupProvider.notifier).refreshRemoteList());
  }
}

/// Listens for app resume and connectivity to flush the Drive backup queue.
@Riverpod(keepAlive: true)
class BackupQueueManager extends _$BackupQueueManager
    with WidgetsBindingObserver {
  ConnectivityStatus? _lastConnectivity;

  /// True after a real backgrounding (paused/hidden), not mere inactive
  /// (screenshot, permission sheet, notification shade).
  bool _sawBackgroundPause = false;

  @override
  void build() {
    final binding = WidgetsBinding.instance..addObserver(this);
    ref
      ..listen(connectivityStatusProvider, _onConnectivityStream)
      ..onDispose(() => binding.removeObserver(this));
    unawaited(_bootstrapConnectivity());
  }

  Future<void> _bootstrapConnectivity() async {
    _lastConnectivity =
        await ref.read(connectivityServiceProvider).currentStatus();
    if (_lastConnectivity == ConnectivityStatus.online) {
      unawaited(_resumePendingCloudSyncIfNeeded());
    }
  }

  void _onConnectivityStream(
    AsyncValue<ConnectivityStatus>? previous,
    AsyncValue<ConnectivityStatus> next,
  ) {
    if (next case AsyncData(value: final status)) {
      final wasOffline = _lastConnectivity == ConnectivityStatus.offline;
      _lastConnectivity = status;
      if (wasOffline && status == ConnectivityStatus.online) {
        unawaited(_onBackOnline());
      }
    }
  }

  Future<void> _onBackOnline() async {
    await _ensureAutoBackupScheduled();
    await _resumePendingCloudSyncIfNeeded();
  }

  Future<void> _resumePendingCloudSyncIfNeeded() async {
    try {
      final session = await ref.read(authRepositoryProvider).getSessionState();
      if (session != AuthSessionState.linked) {
        return;
      }

      final flagged = await PendingCloudSyncStore.hasPending();
      final queue =
          await ref.read(backupQueueRepositoryProvider).getPendingRetryable();
      if (!flagged && queue.isEmpty) {
        return;
      }
      await _runQueueAndPublishHints();
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupQueueManager._resumePendingCloudSyncIfNeeded',
      );
    }
  }

  Future<void> _runQueueAndPublishHints() async {
    try {
      final settingsResult = await ref.read(settingsRepositoryProvider).get();
      final locale = settingsResult.fold((_) => 'ar', (settings) => settings.locale);
      final notify = ref.read(notifyAutoBackupOutcomeUseCaseProvider);

      await notify(
        AutoBackupNotificationEvent.inProgress,
        locale: locale,
      );

      final report = await ref.read(processBackupQueueUseCaseProvider).call();
      ref
          .read(backupSyncStatusProvider.notifier)
          .applyQueueProcessReport(report);
      await ref
          .read(backupSyncStatusProvider.notifier)
          .refreshPendingCloudFlag();
      final queue =
          await ref.read(backupQueueRepositoryProvider).getPendingRetryable();
      if (queue.isEmpty) {
        await PendingCloudSyncStore.clear();
        await ref
            .read(backupSyncStatusProvider.notifier)
            .refreshPendingCloudFlag();
      }

      if (report.sawNeedsReauth) {
        await notify(
          AutoBackupNotificationEvent.needsReauth,
          locale: locale,
        );
      } else if (report.sawQuotaExceeded) {
        await notify(
          AutoBackupNotificationEvent.quotaExceeded,
          locale: locale,
        );
      } else if (report.sawTransientNetworkFailure) {
        await notify(
          AutoBackupNotificationEvent.willRetry,
          locale: locale,
        );
      } else if (queue.isEmpty) {
        await notify(
          AutoBackupNotificationEvent.success,
          locale: locale,
        );
      }
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupQueueManager._runQueueAndPublishHints',
      );
    }
  }

  Future<void> _ensureAutoBackupScheduled() async {
    try {
      final settingsResult = await ref.read(settingsRepositoryProvider).get();
      await settingsResult.fold(
        (_) async {},
        AutoBackupScheduler.ensureScheduled,
      );
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupQueueManager._ensureAutoBackupScheduled',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _sawBackgroundPause = true;
      case AppLifecycleState.resumed:
        if (!_sawBackgroundPause) {
          // Screenshot / system overlay: inactive→resumed without pause.
          // Running auth refresh here flashed AsyncLoading and rebuilt the
          // backup screen (fade-in) as if the page reloaded.
          return;
        }
        _sawBackgroundPause = false;
        // Never run silent auth while interactive sign-in / grant UI is open —
        // resume mid-picker previously re-entered auth and stacked Google UIs.
        final signInBusy = ref.read(signInControllerProvider).isLoading;
        final grantBusy =
            ref.read(driveOfflineGrantControllerProvider).isLoading;
        if (!signInBusy && !grantBusy) {
          unawaited(_refreshDriveSessionOnResume());
        }
        unawaited(_ensureAutoBackupScheduled());
        unawaited(_resumePendingCloudSyncIfNeeded());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Proactively warms PKCE credentials on real resume so a stale access
  /// token does not surface as sticky `needs_reauth` after overnight idle.
  ///
  /// PKCE-only — never calls GSI lightweight auth (Android One Tap).
  /// Does not bounce [AuthState] through [AsyncLoading] (that caused a
  /// visible signed-out→signed-in flicker on the backup screen).
  Future<void> _refreshDriveSessionOnResume() async {
    try {
      final hasGrant =
          await ref.read(authRepositoryProvider).hasDriveOfflineGrant();
      if (!hasGrant) {
        return;
      }
      final status =
          await ref.read(googleAuthDsProvider).ensureDriveCredential();
      switch (status) {
        case DriveCredentialStatus.ready:
          await ref.read(authStateProvider.notifier).reconcileQuietly();
        case DriveCredentialStatus.revoked:
          await ref.read(authStateProvider.notifier).reconcileQuietly();
          ref.invalidate(driveOfflineGrantReadyProvider);
        case DriveCredentialStatus.unavailable:
          break;
      }
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'BackupQueueManager._refreshDriveSessionOnResume',
      );
    }
  }
}

// ── Backup state ─────────────────────────────────────────────────────────────

/// Immutable snapshot of the backup screen's display state.
class BackupState {
  const BackupState({
    this.backups = const [],
    this.isLoading = false,
    this.isCreating = false,
    this.isRestoring = false,
    this.lastFailure,
  });

  final List<BackupMetadata> backups;
  final bool isLoading;
  final bool isCreating;
  final bool isRestoring;
  final Failure? lastFailure;

  BackupState copyWith({
    List<BackupMetadata>? backups,
    bool? isLoading,
    bool? isCreating,
    bool? isRestoring,
    Failure? lastFailure,
    bool clearLastFailure = false,
  }) {
    return BackupState(
      backups: backups ?? this.backups,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isRestoring: isRestoring ?? this.isRestoring,
      lastFailure: clearLastFailure
          ? null
          : (lastFailure ?? this.lastFailure),
    );
  }
}

/// Manages the [BackupState] for the backup screen.
///
/// Exposes:
/// - [createBackup] — creates an encrypted local `.daftar` backup.
/// - [restoreBackup] — validates checksum, decrypts, and swaps the DB.
/// - [deleteBackup] — removes the backup file and metadata record.
/// - [softRestart] — re-opens the DB and re-inserts cached metadata.
///
/// Uses `keepAlive: true` to prevent mid-operation disposal during
/// dialog navigation.
@Riverpod(keepAlive: true)
class BackupNotifier extends _$BackupNotifier {
  @override
  BackupState build() {
    unawaited(_loadBackups());
    return const BackupState(isLoading: true);
  }

  Future<void> _loadBackups() async {
    final result = await ref.read(backupRepositoryProvider).listBackups();
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        lastFailure: failure,
      ),
      (list) => state = state.copyWith(
        isLoading: false,
        backups: list,
        clearLastFailure: true,
      ),
    );
  }

  /// Creates an encrypted local `.daftar` backup.
  ///
  /// Returns `true` on success.
  Future<bool> createBackup() async {
    state = state.copyWith(isCreating: true, clearLastFailure: true);
    try {
      final result = await ref.read(createLocalBackupUseCaseProvider).call();
      return result.fold(
        (failure) {
          state = state.copyWith(lastFailure: failure);
          return false;
        },
        (metadata) {
          state = state.copyWith(
            backups: [metadata, ...state.backups],
          );
          return true;
        },
      );
    } on Object catch (_) {
      state = state.copyWith(
        lastFailure: const ValidationFailure(
          '',
          code: 'unknown',
        ),
      );
      return false;
    } finally {
      state = state.copyWith(isCreating: false);
    }
  }

  /// Restores the database from an encrypted `.daftar` file.
  ///
  /// Returns `true` on success, `false` on failure.
  ///
  /// **IMPORTANT:** On success the DB connection is DEAD. The caller
  /// MUST call [softRestart] immediately after to re-initialize.
  Future<bool> restoreBackup(File file, String checksum) async {
    state = state.copyWith(isRestoring: true, clearLastFailure: true);
    try {
      final result = await ref
          .read(restoreBackupUseCaseProvider)
          .call(
            RestoreBackupParams(
              backupFilePath: file.path,
              expectedChecksum: checksum,
            ),
          );
      return result.fold(
        (failure) {
          state = state.copyWith(lastFailure: failure, isRestoring: false);
          return false;
        },
        (_) => true,
      );
    } on Object catch (_) {
      state = state.copyWith(
        lastFailure: const ValidationFailure(
          '',
          code: 'unknown',
        ),
        isRestoring: false,
      );
      return false;
    } finally {
      state = state.copyWith(isRestoring: false);
    }
  }

  /// Re-opens the database and re-inserts cached backup metadata.
  ///
  /// **Solves the "Time Paradox":** The backed-up DB was captured
  /// *before* its own metadata row was inserted. When restored, that
  /// row is missing. This method re-inserts all known metadata rows
  /// from the in-memory cache into the fresh database, ensuring
  /// backup history survives the DB swap.
  ///
  /// **Solves the "Stuck State":** Invalidates this provider at the
  /// end, which forces `build()` to re-run, resetting `isRestoring`
  /// and all other flags to their defaults.
  Future<void> softRestart(List<BackupMetadata> cachedMetadata) async {
    // Step 1: Open a fresh database connection on the restored file.
    final documentsDirectory = await ref.read(
      appDocumentsDirectoryProvider.future,
    );
    final freshDb = await openDatabase(documentsDirectory: documentsDirectory);

    // Step 2: Swap the active database source and invalidate the provider
    // chain so the next read rebuilds against the restored file.
    activeDatabase = freshDb;

    // Step 3: Re-insert cached backup metadata into the restored DB.
    // Algorithm: Convert domain entities → Drift companions, then
    // bulk-insert with insertOrReplace to handle any rows that already
    // existed in the restored DB.
    if (cachedMetadata.isNotEmpty) {
      try {
        final freshDs = BackupLocalDs(
          freshDb,
          documentsDirectoryResolver: () =>
              ref.read(appDocumentsDirectoryProvider.future),
          publicExportEnabledResolver: () =>
              ref.read(backupPublicExportEnabledProvider),
        );
        final companions = cachedMetadata.map((m) => m.toCompanion()).toList();
        await freshDs.bulkInsertMetadata(companions);
      } on Object {
        // Best-effort: if metadata re-insert fails, the restore itself
        // already succeeded — the user's financial data is intact.
        // Metadata will simply rebuild as new backups are created.
      }
    }

    // Step 4: Reset this notifier before invalidating it so listeners
    // never observe stale post-restore state.
    state = const BackupState(isLoading: true);

    ref
      ..invalidate(appDatabaseProvider)
      ..invalidate(backupLocalDsProvider)
      ..invalidate(backupRepositoryProvider)
      ..invalidateSelf();

    // Step 5: Rebuild against the fresh DB source and reload the list.
  }

  /// Deletes a backup record and its physical file.
  ///
  /// Returns `true` on success.
  Future<bool> deleteBackup(String id) async {
    final result = await ref.read(backupRepositoryProvider).deleteBackup(id);
    return result.fold(
      (failure) {
        state = state.copyWith(lastFailure: failure);
        return false;
      },
      (_) {
        state = state.copyWith(
          backups: state.backups.where((b) => b.id != id).toList(),
        );
        return true;
      },
    );
  }

  /// Triggers a manual refresh of the backup list.
  Future<void> refresh() => _loadBackups();
}

// ── Google Drive backup UI state ─────────────────────────────────────────────

/// Active Drive transfer kind for progress UI.
enum DriveTransferKind { upload, download }

/// Snapshot for the Google Drive section on the backup screen.
class DriveBackupState {
  const DriveBackupState({
    this.remoteBackups = const [],
    this.isLoadingList = false,
    this.transferKind,
    this.progress = 0,
    this.lastFailure,
  });

  final List<GoogleDriveRemoteBackupItem> remoteBackups;
  final bool isLoadingList;
  final DriveTransferKind? transferKind;
  final double progress;
  final Failure? lastFailure;

  bool get isTransferring => transferKind != null;

  DriveBackupState copyWith({
    List<GoogleDriveRemoteBackupItem>? remoteBackups,
    bool? isLoadingList,
    DriveTransferKind? transferKind,
    bool clearTransfer = false,
    double? progress,
    Failure? lastFailure,
    bool clearFailure = false,
  }) {
    return DriveBackupState(
      remoteBackups: remoteBackups ?? this.remoteBackups,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      transferKind: clearTransfer ? null : (transferKind ?? this.transferKind),
      progress: progress ?? this.progress,
      lastFailure: clearFailure ? null : (lastFailure ?? this.lastFailure),
    );
  }
}

/// Manages Drive list, upload, download, and delete for the backup screen.
@Riverpod(keepAlive: true)
class DriveBackup extends _$DriveBackup {
  Timer? _progressTimer;
  bool _cancelRequested = false;
  Future<void>? _remoteListInFlight;

  @override
  DriveBackupState build() {
    ref.onDispose(() => _progressTimer?.cancel());
    return const DriveBackupState();
  }

  void scheduleRemoteListLoad() {
    unawaited(refreshRemoteList());
  }

  void _startProgressSimulation() {
    _cancelRequested = false;
    _progressTimer?.cancel();
    state = state.copyWith(progress: 0.04);
    _progressTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (_cancelRequested) {
        return;
      }
      final next = (state.progress + 0.018).clamp(0.0, 0.92);
      state = state.copyWith(progress: next);
    });
  }

  void _finishProgress() {
    _progressTimer?.cancel();
    state = state.copyWith(progress: 1);
  }

  void _clearProgress() {
    _progressTimer?.cancel();
    state = state.copyWith(clearTransfer: true, progress: 0);
  }

  Future<void> refreshRemoteList() {
    final inFlight = _remoteListInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshRemoteList();
    _remoteListInFlight = future;
    return future.whenComplete(() {
      if (identical(_remoteListInFlight, future)) {
        _remoteListInFlight = null;
      }
    });
  }

  /// Loads the complete Drive catalog for restore (always hits the network).
  Future<void> loadRestoreCatalog() {
    _remoteListInFlight = null;
    return refreshRemoteList();
  }

  Future<void> _refreshRemoteList() async {
    final session = await ref.read(authStateProvider.future);
    if (session != AuthSessionState.linked) {
      state = const DriveBackupState();
      return;
    }

    state = state.copyWith(isLoadingList: true, clearFailure: true);
    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: true);

    final result = await ref
        .read(downloadDriveBackupUseCaseProvider)
        .listAvailableBackups();

    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: false);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingList: false,
          lastFailure: failure,
        );
        ref
            .read(backupSyncStatusProvider.notifier)
            .applyQueueProcessReport(
              BackupQueueProcessReport(
                sawNeedsReauth:
                    failure is AuthFailure && _isHardDriveAuthFailure(failure),
                sawQuotaExceeded: failure is QuotaExceededFailure,
                sawTransientNetworkFailure:
                    failure is NetworkFailure ||
                    (failure is AuthFailure &&
                        !_isHardDriveAuthFailure(failure)),
              ),
            );
      },
      (list) {
        state = state.copyWith(
          isLoadingList: false,
          remoteBackups: list,
          clearFailure: true,
        );
      },
    );
  }

  /// Encrypts locally and uploads the latest backup to Drive.
  Future<bool> uploadToDrive() async {
    if (state.isTransferring) {
      return false;
    }

    state = state.copyWith(
      transferKind: DriveTransferKind.upload,
      clearFailure: true,
    );
    _startProgressSimulation();
    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: true);

    final result = await ref.read(uploadDriveBackupUseCaseProvider).call();

    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: false);

    if (_cancelRequested) {
      _clearProgress();
      return false;
    }

    return result.fold(
      (failure) {
        _clearProgress();
        state = state.copyWith(
          lastFailure: failure,
        );
        ref
            .read(backupSyncStatusProvider.notifier)
            .applyQueueProcessReport(
              BackupQueueProcessReport(
                sawNeedsReauth:
                    failure is AuthFailure && _isHardDriveAuthFailure(failure),
                sawQuotaExceeded: failure is QuotaExceededFailure,
                sawTransientNetworkFailure:
                    failure is NetworkFailure ||
                    (failure is AuthFailure &&
                        !_isHardDriveAuthFailure(failure)),
              ),
            );
        return false;
      },
      (_) {
        _finishProgress();
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!ref.mounted) {
            return;
          }
          _clearProgress();
          unawaited(refreshRemoteList());
        });
        return true;
      },
    );
  }

  /// Downloads and restores a remote backup by Drive [fileId].
  Future<bool> restoreFromDrive(String fileId) async {
    if (state.isTransferring) {
      return false;
    }

    state = state.copyWith(
      transferKind: DriveTransferKind.download,
      clearFailure: true,
    );
    _startProgressSimulation();
    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: true);

    final result = await ref
        .read(downloadDriveBackupUseCaseProvider)
        .restoreBackup(fileId);

    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: false);

    if (_cancelRequested) {
      _clearProgress();
      return false;
    }

    return result.fold(
      (failure) {
        _clearProgress();
        state = state.copyWith(
          lastFailure: failure,
        );
        ref
            .read(backupSyncStatusProvider.notifier)
            .applyQueueProcessReport(
              BackupQueueProcessReport(
                sawNeedsReauth:
                    failure is AuthFailure && _isHardDriveAuthFailure(failure),
                sawQuotaExceeded: failure is QuotaExceededFailure,
                sawTransientNetworkFailure:
                    failure is NetworkFailure ||
                    (failure is AuthFailure &&
                        !_isHardDriveAuthFailure(failure)),
              ),
            );
        return false;
      },
      (_) {
        _finishProgress();
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (!ref.mounted) {
            return;
          }
          _clearProgress();
        });
        return true;
      },
    );
  }

  /// Deletes a remote Drive backup.
  Future<bool> deleteRemote(String fileId) async {
    final result = await ref
        .read(deleteDriveBackupUseCaseProvider)
        .call(fileId);
    return result.fold(
      (failure) {
        state = state.copyWith(
          lastFailure: failure,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          remoteBackups: state.remoteBackups
              .where((b) => b.id != fileId)
              .toList(),
          clearFailure: true,
        );
        ref.read(backupSyncStatusProvider.notifier).clearQuotaExceededHint();
        return true;
      },
    );
  }

  /// Cancels the in-flight progress UI (best-effort; HTTP may still complete).
  void cancelTransfer() {
    _cancelRequested = true;
    _clearProgress();
    ref
        .read(backupSyncStatusProvider.notifier)
        .setForegroundDriveBusy(busy: false);
  }

  bool _isHardDriveAuthFailure(AuthFailure failure) {
    final code = failure.code;
    return code == 'google_not_signed_in' ||
        code == 'canceled' ||
        code == kDriveRefreshTokenRevokedFailureCode;
  }

  /// Flushes the offline upload queue now.
  Future<void> retryQueueNow() async {
    ref.read(backupSyncStatusProvider.notifier).clearDriveRetryScheduledHint();
    final report = await ref.read(processBackupQueueUseCaseProvider).call();
    ref.read(backupSyncStatusProvider.notifier).applyQueueProcessReport(report);
    await refreshRemoteList();
  }
}
