import 'dart:io';

import 'package:daftar/application/auth/handle_google_account_change_use_case.dart';
import 'package:daftar/application/auth/reconcile_drift_identity_use_case.dart';
import 'package:daftar/application/auth/session_bootstrap_coordinator.dart';
import 'package:daftar/application/auth/session_bootstrap_use_case.dart';
import 'package:daftar/application/auto_backup/auto_backup_diagnostics_log.dart';
import 'package:daftar/application/auto_backup/auto_backup_policy.dart';
import 'package:daftar/application/auto_backup/auto_backup_schedule_store.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/application/backup/enqueue_drive_backup_upload_use_case.dart';
import 'package:daftar/application/backup/ensure_drive_session.dart';
import 'package:daftar/application/backup/notify_auto_backup_outcome_use_case.dart';
import 'package:daftar/application/backup/process_backup_queue_use_case.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/backup_auto_notification_strings.dart';
import 'package:daftar/core/services/auth_session_store.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/core/services/storage_service.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/datasources/local/settings_local_ds.dart';
import 'package:daftar/data/datasources/remote/auth_silent_sign_in_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/drive_session_gateway_impl.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/auth_repository_impl.dart';
import 'package:daftar/data/repositories/backup_queue_repository_impl.dart';
import 'package:daftar/data/repositories/backup_repository_impl.dart';
import 'package:daftar/data/repositories/google_drive_backup_remote_repository_impl.dart';
import 'package:daftar/data/repositories/google_identity_repository_impl.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/data/repositories/settings_repository_impl.dart';
import 'package:daftar/data/services/backup_notification_client.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/enums/auto_backup_notification_event.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/services/drive_session_gateway.dart';
import 'package:flutter/widgets.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path_provider/path_provider.dart';

class _AttemptResult {
  const _AttemptResult({required this.nextDelay}) : cancelChain = false;

  const _AttemptResult.cancel()
      : nextDelay = Duration.zero,
        cancelChain = true;

  final Duration nextDelay;
  final bool cancelChain;
}

/// Headless Android auto-backup + queue drain runner.
abstract final class AutoBackupRunner {
  static final NotifyAutoBackupOutcomeUseCase _notifyUseCase =
      NotifyAutoBackupOutcomeUseCase(
    BackupNotificationClient.instance,
    const BackupAutoNotificationStrings(),
  );

  /// Always returns `true` so WorkManager does not OS-retry beside the chain.
  static Future<bool> runAutoBackup() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppDatabase? database;
    var nextDelay = const Duration(minutes: 30);
    var cancelChain = false;
    var locale = 'ar';
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      database = await openDatabase(documentsDirectory: documentsDirectory);
      final context = _HeadlessContext(
        database: database,
        documentsDirectory: documentsDirectory,
      );
      final settings = await context.readSettings();
      if (settings != null) {
        locale = settings.locale;
        nextDelay = AutoBackupPolicy.intervalFor(settings);
      }
      final attempt = await _runAutoBackupCore(context);
      nextDelay = attempt.nextDelay;
      cancelChain = attempt.cancelChain;
      await AutoBackupScheduleStore.recordCompleted();
      return true;
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupRunner.runAutoBackup',
      );
      await _notifyUseCase(
        AutoBackupNotificationEvent.failed,
        locale: locale,
      );
      nextDelay = AutoBackupPolicy.transientBackoffFor(nextDelay);
      cancelChain = false;
      return true;
    } finally {
      await database?.close();
      // Re-arm the Doze-piercing alarm only — never REPLACE a running
      // WorkManager unique name (that cancels this isolate mid-flight).
      if (cancelChain) {
        await AutoBackupScheduler.cancelAll();
      } else {
        await AutoBackupScheduler.scheduleNextRun(
          interval: nextDelay,
          locale: locale,
        );
      }
    }
  }

  /// Returns `false` only for transient network so OS can retry queue drain.
  static Future<bool> runQueueDrain() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppDatabase? database;
    var locale = 'ar';
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      database = await openDatabase(documentsDirectory: documentsDirectory);
      final context = _HeadlessContext(
        database: database,
        documentsDirectory: documentsDirectory,
      );
      final settings = await context.readSettings();
      if (settings != null) {
        locale = settings.locale;
      }
      return await _runQueueDrainCore(context, settings: settings);
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupRunner.runQueueDrain',
      );
      await _notifyUseCase(
        AutoBackupNotificationEvent.failed,
        locale: locale,
      );
      return false;
    } finally {
      await database?.close();
    }
  }

  static Future<_AttemptResult> _runAutoBackupCore(
    _HeadlessContext context,
  ) async {
    final bundle = await context.authSessionStore.read();
    final settings = await context.readSettings();
    final interval = settings != null
        ? AutoBackupPolicy.intervalFor(settings)
        : const Duration(minutes: 30);

    if (bundle == null || settings == null) {
      return const _AttemptResult.cancel();
    }
    final locale = settings.locale;
    final googleAccountId = settings.googleAccountId;
    if (!settings.driveAutoBackupEnabled) {
      return const _AttemptResult.cancel();
    }
    if (googleAccountId == null || googleAccountId.isEmpty) {
      return const _AttemptResult.cancel();
    }
    if (!bundle.hasDriveOfflineGrant) {
      await _recordOutcome(
        context,
        outcome: 'failed',
        failureCode: 'needs_reauth',
      );
      await PendingCloudSyncStore.setPending(value: true);
      await context.notifyUseCase(
        AutoBackupNotificationEvent.needsReauth,
        locale: locale,
      );
      return _AttemptResult(nextDelay: interval);
    }

    if (AutoBackupPolicy.shouldSkip(settings: settings, interval: interval)) {
      await _recordOutcome(context, outcome: 'skipped');
      await AutoBackupDiagnosticsLog.append(event: 'skipped', source: 'runner');
      return _AttemptResult(
        nextDelay: AutoBackupPolicy.delayUntilEligible(
          settings: settings,
          interval: interval,
        ),
      );
    }

    await context.notifyUseCase(
      AutoBackupNotificationEvent.inProgress,
      locale: locale,
    );

    try {
      final pendingQueue =
          await context.backupQueueRepository.getPendingRetryable();
      if (pendingQueue.isNotEmpty) {
        final drained = await _runQueueDrainCore(context, settings: settings);
        // _runQueueDrainCore already posted the terminal notification.
        if (drained) {
          await _recordOutcome(context, outcome: 'success', clearFailure: true);
          return _AttemptResult(nextDelay: interval);
        }
        return _AttemptResult(
          nextDelay: AutoBackupPolicy.transientBackoffFor(interval),
        );
      }

      final session = await ensureHeadlessDriveSession(
        authRepository: context.authRepository,
        driveSessionGateway: context.driveSessionGateway,
      );
      if (session case Left(value: final failure)) {
        return _handleFailure(
          context: context,
          failure: failure,
          interval: interval,
          locale: locale,
          googleAccountId: googleAccountId,
        );
      }

      final upload = await context.uploadUseCase.call();
      switch (upload) {
        case Left(value: final failure):
          return _handleFailure(
            context: context,
            failure: failure,
            interval: interval,
            locale: locale,
            googleAccountId: googleAccountId,
          );
        case Right():
          await _recordOutcome(context, outcome: 'success', clearFailure: true);
          await AutoBackupDiagnosticsLog.append(
            event: 'success',
            source: 'runner',
          );
          await context.notifyUseCase(
            AutoBackupNotificationEvent.success,
            locale: locale,
          );
          return _AttemptResult(nextDelay: interval);
      }
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupRunner._runAutoBackupCore',
      );
      await context.notifyUseCase(
        AutoBackupNotificationEvent.failed,
        locale: locale,
      );
      await AutoBackupDiagnosticsLog.append(event: 'failed', source: 'runner');
      return _AttemptResult(
        nextDelay: AutoBackupPolicy.transientBackoffFor(interval),
      );
    }
  }

  static Future<_AttemptResult> _handleFailure({
    required _HeadlessContext context,
    required Failure failure,
    required Duration interval,
    required String locale,
    required String googleAccountId,
  }) async {
    await _appendAudit(
      context: context,
      googleAccountId: googleAccountId,
      failure: failure,
    );

    if (isStickyNeedsReauthFailure(failure)) {
      await _recordOutcome(
        context,
        outcome: 'failed',
        failureCode: 'needs_reauth',
      );
      await PendingCloudSyncStore.setPending(value: true);
      await context.notifyUseCase(
        AutoBackupNotificationEvent.needsReauth,
        locale: locale,
      );
      return _AttemptResult(nextDelay: interval);
    }
    if (failure is QuotaExceededFailure) {
      await _recordOutcome(
        context,
        outcome: 'failed',
        failureCode: 'storage_quota_exceeded',
      );
      await context.notifyUseCase(
        AutoBackupNotificationEvent.quotaExceeded,
        locale: locale,
      );
      return _AttemptResult(nextDelay: interval);
    }
    if (failure is StorageFullFailure) {
      await _recordOutcome(
        context,
        outcome: 'failed',
        failureCode: 'device_storage_full',
      );
      await context.notifyUseCase(
        AutoBackupNotificationEvent.storageFull,
        locale: locale,
      );
      return _AttemptResult(nextDelay: interval);
    }
    if (isTransientBackgroundDriveFailure(failure)) {
      await _recordOutcome(
        context,
        outcome: 'failed',
        failureCode: failure.code ?? 'network_unavailable',
      );
      await PendingCloudSyncStore.setPending(value: true);
      await context.notifyUseCase(
        AutoBackupNotificationEvent.willRetry,
        locale: locale,
      );
      return _AttemptResult(
        nextDelay: AutoBackupPolicy.transientBackoffFor(interval),
      );
    }
    await _recordOutcome(
      context,
      outcome: 'failed',
      failureCode: failure.code ?? 'unknown',
    );
    await context.notifyUseCase(
      AutoBackupNotificationEvent.failed,
      locale: locale,
    );
    return _AttemptResult(nextDelay: interval);
  }

  static Future<bool> _runQueueDrainCore(
    _HeadlessContext context, {
    AppSettings? settings,
  }) async {
    final resolved = settings ?? await context.readSettings();
    final locale = resolved?.locale ?? 'ar';
    await context.notifyUseCase(
      AutoBackupNotificationEvent.inProgress,
      locale: locale,
    );
    try {
      final report = await context.processBackupQueueUseCase.call();
      if (report.sawNeedsReauth) {
        await context.notifyUseCase(
          AutoBackupNotificationEvent.needsReauth,
          locale: locale,
        );
        return true;
      }
      if (report.sawQuotaExceeded) {
        await context.notifyUseCase(
          AutoBackupNotificationEvent.quotaExceeded,
          locale: locale,
        );
        return true;
      }
      if (report.sawTransientNetworkFailure) {
        await context.notifyUseCase(
          AutoBackupNotificationEvent.willRetry,
          locale: locale,
        );
        return false;
      }
      await context.notifyUseCase(
        AutoBackupNotificationEvent.success,
        locale: locale,
      );
      return true;
    } on Object {
      await context.notifyUseCase(
        AutoBackupNotificationEvent.willRetry,
        locale: locale,
      );
      return false;
    }
  }

  static Future<void> _recordOutcome(
    _HeadlessContext context, {
    required String outcome,
    String? failureCode,
    bool clearFailure = false,
  }) async {
    await context.settingsRepository.update(
      UpdateSettingsParams(
        lastAutoBackupOutcome: outcome,
        lastAutoBackupFailureCode: failureCode,
        clearLastAutoBackupFailure: clearFailure,
      ),
    );
  }

  static Future<void> _appendAudit({
    required _HeadlessContext context,
    required String googleAccountId,
    required Failure failure,
  }) async {
    try {
      await context.auditLogLocalDataSource.appendLog(
        AuditLogModel(
          id: UuidUtil.generate(),
          entityType: 'auto_backup',
          entityId: googleAccountId,
          action: 'AUTO_BACKUP_AUTH_DEFER',
          payload: encodePayload({
            'failureCode': failure.code,
            'failureMessage': failure.message,
          }),
          timestamp: DateTime.now().toUtc(),
          deviceId: repositoryDeviceId,
        ),
      );
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupRunner._appendAudit',
      );
    }
  }
}

final class _HeadlessContext {
  _HeadlessContext({
    required AppDatabase database,
    required Directory documentsDirectory,
  })  : authSessionStore = AuthSessionStore(),
        auditLogLocalDataSource = AuditLogLocalDataSource(database),
        settingsRepository = SettingsRepositoryImpl(
          settingsLocalDataSource: SettingsLocalDataSource(database),
          auditLogLocalDataSource: AuditLogLocalDataSource(database),
        ),
        notifyUseCase = NotifyAutoBackupOutcomeUseCase(
          BackupNotificationClient.instance,
          const BackupAutoNotificationStrings(),
        ),
        _database = database,
        _documentsDirectory = documentsDirectory {
    googleAuthDs = GoogleAuthDs(authSessionStore: authSessionStore);
    driveSessionGateway = DriveSessionGatewayImpl(googleAuthDs);

    final backupLocalDs = BackupLocalDs(
      _database,
      documentsDirectoryResolver: () async => _documentsDirectory,
      publicExportEnabledResolver: () => false,
    );
    final backupQueueLocalDs = BackupQueueLocalDs(_database);
    final reconcile = ReconcileDriftIdentityUseCase(settingsRepository);
    final silentGateway = AuthSilentSignInGatewayImpl(googleAuthDs);
    final bootstrapUseCase = SessionBootstrapUseCase(
      authSessionStore,
      settingsRepository,
      silentGateway,
      reconcile,
    );
    final bootstrapCoordinator = SessionBootstrapCoordinator(bootstrapUseCase);
    final identityRepo = GoogleIdentityRepositoryImpl(
      database: _database,
      backupLocalDs: backupLocalDs,
      backupQueueLocalDs: backupQueueLocalDs,
      auditLogLocalDataSource: auditLogLocalDataSource,
    );
    final accountChange = HandleGoogleAccountChangeUseCase(
      identityRepo,
      authSessionStore,
      cancelBackgroundSync: AutoBackupScheduler.cancelAll,
    );

    authRepository = AuthRepositoryImpl(
      googleAuthDs: googleAuthDs,
      authSessionStore: authSessionStore,
      settingsRepository: settingsRepository,
      reconcileDriftIdentityUseCase: reconcile,
      handleGoogleAccountChangeUseCase: accountChange,
      sessionBootstrapCoordinator: bootstrapCoordinator,
      backupLocalDs: backupLocalDs,
      backupQueueLocalDs: backupQueueLocalDs,
      auditLogLocalDataSource: auditLogLocalDataSource,
    );
    backupQueueRepository = BackupQueueRepositoryImpl(localDs: backupQueueLocalDs);
    final enqueue = EnqueueDriveBackupUploadUseCase(backupQueueRepository);
    uploadUseCase = UploadDriveBackupUseCase(
      authRepository: authRepository,
      settingsRepository: settingsRepository,
      backupRepository: BackupRepositoryImpl(backupLocalDs: backupLocalDs),
      driveRemoteRepository: GoogleDriveBackupRemoteRepositoryImpl(
        googleAuthDs: googleAuthDs,
      ),
      storageService: StorageService(),
      enqueueDriveBackupUploadUseCase: enqueue,
    );
    processBackupQueueUseCase = ProcessBackupQueueUseCase(
      authRepository: authRepository,
      backupQueueRepository: backupQueueRepository,
      uploadDriveBackupUseCase: uploadUseCase,
    );
  }

  final AppDatabase _database;
  final Directory _documentsDirectory;
  final AuthSessionStore authSessionStore;
  final AuditLogLocalDataSource auditLogLocalDataSource;
  final SettingsRepository settingsRepository;
  final NotifyAutoBackupOutcomeUseCase notifyUseCase;
  late final GoogleAuthDs googleAuthDs;
  late final DriveSessionGateway driveSessionGateway;
  late final AuthRepositoryImpl authRepository;
  late final BackupQueueRepositoryImpl backupQueueRepository;
  late final UploadDriveBackupUseCase uploadUseCase;
  late final ProcessBackupQueueUseCase processBackupQueueUseCase;

  Future<AppSettings?> readSettings() async {
    final result = await settingsRepository.get();
    return result.fold((_) => null, (s) => s);
  }
}
