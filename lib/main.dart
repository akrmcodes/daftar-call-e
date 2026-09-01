import 'dart:async';

import 'package:daftar/app/app.dart';
import 'package:daftar/app/database_recovery_app.dart';
import 'package:daftar/application/auto_backup/auto_backup_dispatcher.dart';
import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/bootstrap.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/database_corruption_exception.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/core/services/database_integrity_service.dart';
import 'package:daftar/core/services/deferred_install_attribution_store.dart';
import 'package:daftar/core/services/fcm_token_scaffold.dart';
import 'package:daftar/core/services/firebase_analytics_consent.dart';
import 'package:daftar/core/services/firebase_preflight_smoke.dart';
import 'package:daftar/core/services/play_install_referrer_service.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/services/backup_notification_client.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/providers/sync_engine_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global reference to the app's [ProviderContainer].
late final ProviderContainer appContainer;

/// The active database instance used by [appDatabaseProvider].
late db.AppDatabase activeDatabase;

void main() async {
  try {
    await _launchMainApp();
  } on DatabaseCorruptionException catch (error, stackTrace) {
    WidgetsFlutterBinding.ensureInitialized();
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'database_corruption_startup',
      ),
    );
    runApp(const DatabaseRecoveryApp());
  }
}

Future<void> _launchMainApp() async {
  final database = await bootstrap();
  activeDatabase = database;
  appContainer = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith((ref) => activeDatabase),
    ],
  );

  await AutoBackupScheduler.initialize(autoBackupDispatcher);

  final notificationService = appContainer.read(notificationServiceProvider);
  await notificationService.init();
  await BackupNotificationClient.instance.ensureReady();

  runApp(
    UncontrolledProviderScope(
      container: appContainer,
      child: const DaftarApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredServices());
    unawaited(_runFirebaseDeferredStartup());
    unawaited(_bootstrapAuthSession());
    unawaited(_runDeferredDatabaseIntegrityCheck());
    // Contest quarantine — Stage 8 disabled (see AppConstants).
    unawaited(_startSyncEngine());
    unawaited(_startDeepLinkListener());
  });
}

/// Applies analytics consent, then optional §0.3.2.1 smoke, then FCM scaffold.
///
/// Consent must complete before smoke Analytics events so collection is on.
Future<void> _runFirebaseDeferredStartup() async {
  await _applyAnalyticsConsentFromSettings();
  await FirebasePreflightSmoke.runIfEnabled();
  await _initializeFcmScaffold();
}

/// Mirrors the persisted analytics preference onto the Firebase Analytics SDK.
Future<void> _applyAnalyticsConsentFromSettings() async {
  try {
    final settingsResult =
        await appContainer.read(settingsRepositoryProvider).get();
    await settingsResult.fold(
      (_) async {},
      (settings) => FirebaseAnalyticsConsent.apply(
        enabled: settings.analyticsEnabled,
      ),
    );
  } on Object catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'analytics_consent_startup',
      ),
    );
  }
}

/// Obtains an FCM token + notification permission (§0.3.2 scaffold only).
Future<void> _initializeFcmScaffold() async {
  try {
    await FcmTokenScaffold.initialize();
  } on Object catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'fcm_scaffold_startup',
      ),
    );
  }
}

Future<void> _startDeepLinkListener() async {
  // Contest quarantine — Stage 8 disabled.
  if (AppConstants.kContestDisableMultiDeviceSync) {
    return;
  }
  try {
    await PlayInstallReferrerService().captureIfNeeded();
    await appContainer.read(deepLinkControllerProvider.future);
    final pending =
        await DeferredInstallAttributionStore().takePendingToken();
    if (pending != null) {
      final controller =
          appContainer.read(deepLinkControllerProvider.notifier);
      if (!controller.wasInitialLinkToken(pending)) {
        await controller.handleToken(pending);
      }
    }
  } on Object catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'deep_link_bootstrap',
      ),
    );
  }
}

Future<void> _startSyncEngine() async {
  // Contest quarantine — Stage 8 disabled.
  if (AppConstants.kContestDisableMultiDeviceSync) {
    return;
  }
  try {
    await appContainer.read(syncEngineControllerProvider.future);
  } on Object catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'sync_engine_bootstrap',
      ),
    );
  }
}

Future<void> _runDeferredDatabaseIntegrityCheck() async {
  try {
    await DatabaseIntegrityService.assertHealthy(activeDatabase);
  } on DatabaseCorruptionException catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'database_corruption_deferred_check',
      ),
    );
  }
}

/// Notification permission after first frame (Activity attached on Android 13+).
Future<void> _initializeDeferredServices() async {
  try {
    final notificationService = appContainer.read(notificationServiceProvider);
    await notificationService.requestPermissions();
  } on Object catch (error, stackTrace) {
    unawaited(
      CrashLogger.recordError(
        error,
        stackTrace,
        reason: 'notification_permission_deferred',
      ),
    );
  }
  await _scheduleDriveAutoBackupFromSettings();
}

Future<void> _bootstrapAuthSession() async {
  final result =
      await appContainer.read(sessionBootstrapCoordinatorProvider).execute();
  await result.fold(
    (failure) async {
      unawaited(
        CrashLogger.recordError(
          failure,
          StackTrace.current,
          reason: 'session_bootstrap_startup',
        ),
      );
    },
    (_) async {
      await appContainer.read(authStateProvider.notifier).refresh();
    },
  );
}

Future<void> _scheduleDriveAutoBackupFromSettings() async {
  final settingsResult =
      await appContainer.read(settingsRepositoryProvider).get();
  // Use ensureScheduled (not applyFromSettings) so cold start cannot
  // REPLACE an armed schedule with a flat 1-hour initial delay.
  await settingsResult.fold(
    (_) async {},
    AutoBackupScheduler.ensureScheduled,
  );
}
