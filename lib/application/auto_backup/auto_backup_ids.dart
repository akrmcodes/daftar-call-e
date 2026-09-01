import 'package:workmanager/workmanager.dart';

/// Unique WorkManager name for the Android auto-backup periodic safety net.
const String kAutoBackupPeriodicUniqueName =
    'com.akrmcodes.daftar.autobackup.periodic';

/// Unique WorkManager name for offline Drive upload queue drain.
const String kAutoBackupQueueUniqueName =
    'com.akrmcodes.daftar.autobackup.queue';

/// Unique WorkManager name for zero-delay alarm→FGS failure fallback.
const String kAutoBackupAlarmFallbackUniqueName =
    'com.akrmcodes.daftar.autobackup.alarm_fallback';

/// Task name handled by the auto-backup Workmanager dispatcher for chain runs
/// and the periodic safety net.
const String kAutoBackupRunTaskName = 'auto_backup_run';

/// Task name handled by the auto-backup Workmanager dispatcher for queue drain.
const String kAutoBackupQueueTaskName = 'auto_backup_queue_drain';

/// Legacy unique names cancelled on every schedule so old builds cannot
/// dual-fire alongside the new alarm + periodic safety net.
const List<String> kLegacyAutoBackupUniqueNames = <String>[
  'com.akrmcodes.daftar.autobackup.chain',
  'com.akrmcodes.daftar.backup.chain',
  'com.akrmcodes.daftar.backup.periodic',
  'com.akrmcodes.daftar.backup.processing',
  'com.akrmcodes.daftar.backup.queue_drain',
];

/// Work constraints for the periodic safety net and queue drain.
///
/// The Doze-piercing AlarmManager path has **no** network constraint so it
/// can fire while the radio is down; the runner itself handles offline
/// (`willRetry`). The safety net still prefers connectivity when available.
Constraints get kAutoBackupWorkConstraints => Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresStorageNotLow: false,
    );

/// Zero-constraint fallback used when FGS start is blocked from the alarm.
Constraints get kAutoBackupAlarmFallbackConstraints => Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresStorageNotLow: false,
    );

/// Catch-up delay when resume/connectivity finds the schedule overdue/stale.
const Duration kAutoBackupCatchUpDelay = Duration(seconds: 5);

/// Bounded backoff after transient auto-backup failure.
const Duration kAutoBackupTransientBackoffCap = Duration(minutes: 5);

/// Default first-fire delay when enabling auto-backup with no prior backup.
const Duration kAutoBackupEnableInitialDelay = Duration(minutes: 1);

/// Android WorkManager minimum periodic interval.
const Duration kAutoBackupMinPeriodicInterval = Duration(minutes: 15);
