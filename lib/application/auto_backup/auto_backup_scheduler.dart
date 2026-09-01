import 'dart:io';
import 'dart:ui' show PluginUtilities;

import 'package:backup_notifier/backup_notifier.dart';
import 'package:daftar/application/auto_backup/auto_backup_ids.dart';
import 'package:daftar/application/auto_backup/auto_backup_policy.dart';
import 'package:daftar/application/auto_backup/auto_backup_schedule_store.dart';
import 'package:daftar/application/auto_backup/auto_backup_service_entrypoint.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:workmanager/workmanager.dart';

/// Android auto-backup scheduling: Doze-piercing AlarmManager + WM safety net.
abstract final class AutoBackupScheduler {
  static final BackupNotifier _notifier = BackupNotifier();

  static Future<void> initialize(void Function() dispatcher) async {
    if (!Platform.isAndroid) {
      return;
    }
    await Workmanager().initialize(dispatcher);
  }

  /// Registers or cancels from [settings] (user toggle / enable path).
  static Future<void> applyFromSettings(
    AppSettings settings, {
    String source = 'apply',
    Duration? forceInitialDelay,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!_shouldSchedule(settings)) {
      await cancelAll();
      return;
    }
    final delay = forceInitialDelay ?? AutoBackupPolicy.initialDelayFor(settings);
    await _armAll(
      settings: settings,
      delay: delay,
      source: source,
      replacePeriodic: true,
    );
  }

  /// Re-arms after a successful / skipped run (full interval from now).
  ///
  /// Does **not** replace a running WorkManager worker — only arms the native
  /// alarm and ensures the periodic safety net exists with KEEP.
  static Future<void> scheduleNextRun({
    required Duration interval,
    AppSettings? settings,
    String locale = 'ar',
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (settings != null && !_shouldSchedule(settings)) {
      await cancelAll();
      return;
    }
    final resolvedLocale = settings?.locale;
    await _armAlarmAndPeriodic(
      delay: interval,
      interval: interval,
      source: 'chain',
      replacePeriodic: false,
      locale: (resolvedLocale != null && resolvedLocale.isNotEmpty)
          ? resolvedLocale
          : locale,
    );
  }

  static Future<void> scheduleQueueDrain() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await Workmanager().registerOneOffTask(
        kAutoBackupQueueUniqueName,
        kAutoBackupQueueTaskName,
        initialDelay: const Duration(minutes: 5),
        constraints: kAutoBackupWorkConstraints,
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupScheduler.scheduleQueueDrain',
      );
    }
  }

  /// Resume / connectivity catch-up: force short delay when overdue or stale.
  ///
  /// Prefer this over [applyFromSettings] on cold start so a flat initial
  /// delay cannot starve an already-armed schedule.
  static Future<void> ensureScheduled(AppSettings settings) async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!_shouldSchedule(settings)) {
      return;
    }
    try {
      final overdue = await AutoBackupScheduleStore.isOverdue(
        const Duration(minutes: 15),
      );
      await _cancelLegacyNames();

      final interval = AutoBackupPolicy.intervalFor(settings);
      final forceCatchUp = AutoBackupPolicy.shouldForceCatchUp(
            settings: settings,
            scheduleOverdue: overdue,
          ) ||
          overdue ||
          AutoBackupPolicy.isStale(settings: settings, interval: interval);

      final delay = forceCatchUp
          ? kAutoBackupCatchUpDelay
          : AutoBackupPolicy.initialDelayFor(settings);

      await _armAll(
        settings: settings,
        delay: delay,
        source: forceCatchUp ? 'catch_up' : 'ensure',
        replacePeriodic: false,
      );
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupScheduler.ensureScheduled',
      );
    }
  }

  /// Cancels the retired one-off chain unique name (legacy cleanup).
  static Future<void> cancelAutoBackupChain() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _cancelLegacyNames();
    } on Object {
      return;
    }
  }

  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _notifier.cancelAutoBackupAlarm();
      await Workmanager().cancelByUniqueName(kAutoBackupPeriodicUniqueName);
      await Workmanager().cancelByUniqueName(kAutoBackupQueueUniqueName);
      await Workmanager().cancelByUniqueName(kAutoBackupAlarmFallbackUniqueName);
      await _cancelLegacyNames();
    } on Object {
      return;
    }
  }

  static bool _shouldSchedule(AppSettings settings) {
    if (!settings.driveAutoBackupEnabled) {
      return false;
    }
    final id = settings.googleAccountId;
    return id != null && id.isNotEmpty;
  }

  static Future<void> _armAll({
    required AppSettings settings,
    required Duration delay,
    required String source,
    required bool replacePeriodic,
  }) async {
    final interval = AutoBackupPolicy.intervalFor(settings);
    await _armAlarmAndPeriodic(
      delay: delay,
      interval: interval,
      source: source,
      replacePeriodic: replacePeriodic,
      locale: settings.locale,
    );
  }

  static Future<void> _armAlarmAndPeriodic({
    required Duration delay,
    required Duration interval,
    required String source,
    required bool replacePeriodic,
    String locale = 'ar',
  }) async {
    try {
      await _cancelLegacyNames();
      final callbackHandle = _resolveCallbackHandle();
      if (callbackHandle == null) {
        await CrashLogger.recordError(
          StateError('auto_backup_missing_callback_handle'),
          StackTrace.current,
          reason: 'AutoBackupScheduler._armAlarmAndPeriodic',
        );
      } else {
        final triggerAt = DateTime.now().toUtc().add(delay);
        await _notifier.scheduleAutoBackupAlarm(
          triggerAtMillis: triggerAt.millisecondsSinceEpoch,
          intervalMillis: interval.inMilliseconds,
          callbackHandle: callbackHandle,
          locale: locale,
        );
      }

      final periodicInterval =
          AutoBackupPolicy.periodicSafetyNetInterval(interval);
      await Workmanager().registerPeriodicTask(
        kAutoBackupPeriodicUniqueName,
        kAutoBackupRunTaskName,
        frequency: periodicInterval,
        initialDelay: delay < periodicInterval ? delay : periodicInterval,
        constraints: kAutoBackupWorkConstraints,
        existingWorkPolicy: replacePeriodic
            ? ExistingPeriodicWorkPolicy.replace
            : ExistingPeriodicWorkPolicy.keep,
      );

      await AutoBackupScheduleStore.recordScheduled(
        nextScheduledAt: DateTime.now().toUtc().add(delay),
        source: source,
      );
      await _notifier.appendDiagnostic(event: 'armed', source: source);
    } on Object catch (error, stack) {
      await CrashLogger.recordError(
        error,
        stack,
        reason: 'AutoBackupScheduler._armAlarmAndPeriodic',
      );
    }
  }

  static int? _resolveCallbackHandle() {
    final handle = PluginUtilities.getCallbackHandle(autoBackupServiceMain);
    return handle?.toRawHandle();
  }

  static Future<void> _cancelLegacyNames() async {
    for (final name in kLegacyAutoBackupUniqueNames) {
      try {
        await Workmanager().cancelByUniqueName(name);
      } on Object {
        // Best-effort cleanup.
      }
    }
  }
}
