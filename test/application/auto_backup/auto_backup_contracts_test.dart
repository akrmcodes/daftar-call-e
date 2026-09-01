import 'dart:io';

import 'package:daftar/application/auto_backup/auto_backup_ids.dart';
import 'package:daftar/application/auto_backup/auto_backup_policy.dart';
import 'package:daftar/application/backup/notify_auto_backup_outcome_use_case.dart';
import 'package:daftar/core/l10n/backup_auto_notification_strings.dart';
import 'package:daftar/domain/constants/backup_notification_ids.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/enums/auto_backup_notification_event.dart';
import 'package:daftar/domain/services/backup_notification_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBackupNotificationPort implements BackupNotificationPort {
  int showCallCount = 0;
  int dismissCallCount = 0;
  final List<int> shownIds = <int>[];

  @override
  Future<void> dismissInProgress() async {
    dismissCallCount++;
  }

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    bool ongoing = false,
    bool urgent = false,
  }) async {
    showCallCount++;
    shownIds.add(id);
  }
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('repo root not found');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('NotifyAutoBackupOutcomeUseCase', () {
    late _RecordingBackupNotificationPort port;
    late NotifyAutoBackupOutcomeUseCase sut;

    setUp(() {
      port = _RecordingBackupNotificationPort();
      sut = NotifyAutoBackupOutcomeUseCase(
        port,
        const BackupAutoNotificationStrings(),
      );
    });

    test('inProgress and success share the same status notification id', () async {
      await sut(AutoBackupNotificationEvent.inProgress, locale: 'ar');
      await sut(AutoBackupNotificationEvent.success, locale: 'ar');

      expect(port.showCallCount, 2);
      expect(port.shownIds, everyElement(BackupNotificationIds.statusNotificationId));
      expect(
        BackupNotificationIds.inProgressNotificationId,
        BackupNotificationIds.statusNotificationId,
      );
      expect(
        BackupNotificationIds.outcomeNotificationId,
        BackupNotificationIds.statusNotificationId,
      );
    });

    test('inProgress posts without dismiss', () async {
      await sut(AutoBackupNotificationEvent.inProgress, locale: 'en');

      expect(port.dismissCallCount, 0);
      expect(port.showCallCount, 1);
    });

    test('resolves Arabic ARB strings for failed event', () {
      const strings = BackupAutoNotificationStrings();
      final copy = strings.resolve(
        AutoBackupNotificationEvent.failed,
        'ar',
      );
      expect(copy.title, 'فشل النسخ الاحتياطي التلقائي');
      expect(
        copy.body,
        'تعذّر رفع النسخة الاحتياطية. افتح دفتر للاطلاع على التفاصيل.',
      );
    });

    test('resolves English ARB strings for retry event', () {
      const strings = BackupAutoNotificationStrings();
      final copy = strings.resolve(
        AutoBackupNotificationEvent.willRetry,
        'en',
      );
      expect(copy.title, 'Backup pending');
      expect(
        copy.body,
        'No internet connection. Upload will resume when you are back online.',
      );
    });
  });

  test('Dart channel IDs match Kotlin AutoBackupChannels', () {
    final kotlin = File(
      '${_repoRoot().path}/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupChannels.kt',
    ).readAsStringSync();
    expect(kotlin, contains('"${BackupNotificationIds.alertsChannelId}"'));
    expect(
      kotlin,
      contains('"${BackupNotificationIds.urgentAlertsChannelId}"'),
    );
    expect(kotlin, contains('IMPORTANCE_HIGH'));
    expect(kotlin, contains('VISIBILITY_PUBLIC'));
    expect(BackupNotificationIds.alertsChannelId, endsWith('_v2'));
    expect(BackupNotificationIds.urgentAlertsChannelId, endsWith('_v2'));
  });

  test('plugin routes show through AutoBackupChannels', () {
    final plugin = File(
      '${_repoRoot().path}/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/BackupNotifierPlugin.kt',
    ).readAsStringSync();
    expect(plugin, contains('AutoBackupChannels.buildNotification'));
    expect(plugin, contains('scheduleAutoBackupAlarm'));
    expect(plugin, contains('areNotificationsEnabled'));
  });

  test('main.dart requests notification permission only after runApp', () {
    final mainSource =
        File('${_repoRoot().path}/lib/main.dart').readAsStringSync();
    final runAppIndex = mainSource.indexOf('runApp(');
    expect(runAppIndex, greaterThan(0));
    expect(
      mainSource.substring(0, runAppIndex).contains('requestPermissions'),
      isFalse,
    );
    expect(mainSource, contains('notificationService.requestPermissions()'));
    expect(mainSource, contains('AutoBackupScheduler.ensureScheduled'));
    expect(mainSource, isNot(contains('AutoBackupNotifications')));
  });

  test('runner never REPLACE-cancels its own WorkManager unique name', () {
    final source = File(
      '${_repoRoot().path}/lib/application/auto_backup/auto_backup_runner.dart',
    ).readAsStringSync();
    expect(source, contains('_AttemptResult.cancel()'));
    expect(source, contains('cancelAll()'));
    expect(source, contains('scheduleNextRun'));
    expect(source, isNot(contains('cancelAutoBackupChain()')));
  });

  test('scheduler unique names match ids', () {
    expect(
      kAutoBackupPeriodicUniqueName,
      'com.akrmcodes.daftar.autobackup.periodic',
    );
    expect(
      kAutoBackupQueueUniqueName,
      'com.akrmcodes.daftar.autobackup.queue',
    );
    expect(kAutoBackupRunTaskName, 'auto_backup_run');
    expect(kAutoBackupQueueTaskName, 'auto_backup_queue_drain');
    expect(
      kLegacyAutoBackupUniqueNames,
      contains('com.akrmcodes.daftar.autobackup.chain'),
    );
  });

  test('cold start uses ensureScheduled not applyFromSettings tear-off', () {
    final mainSource =
        File('${_repoRoot().path}/lib/main.dart').readAsStringSync();
    expect(mainSource, contains('AutoBackupScheduler.ensureScheduled'));
    final applyCount = 'AutoBackupScheduler.applyFromSettings'
        .allMatches(mainSource)
        .length;
    expect(applyCount, 0);
  });

  test('drive section opens settings and battery gate on enable', () {
    final section = File(
      '${_repoRoot().path}/lib/presentation/screens/settings/backup/widgets/drive_backup_section.dart',
    ).readAsStringSync();
    expect(section, contains('openAppSettings'));
    expect(section, contains('AutoBackupBatteryGate'));
    expect(section, isNot(contains('BackupReliabilityCard')));
  });

  test('initialDelayFor is due-time based not flat 1 hour', () {
    final now = DateTime.utc(2026, 8, 9, 12);
    final recent = AppSettings(
      driveAutoBackupEnabled: true,
      lastBackupAt: now.subtract(const Duration(hours: 6)),
    );
    expect(
      AutoBackupPolicy.initialDelayFor(recent, now: now),
      const Duration(hours: 18),
    );

    const never = AppSettings(
      driveAutoBackupEnabled: true,
    );
    expect(
      AutoBackupPolicy.initialDelayFor(never, now: now),
      AutoBackupPolicy.firstRunDelay,
    );

    final overdue = AppSettings(
      driveAutoBackupEnabled: true,
      lastBackupAt: now.subtract(const Duration(hours: 30)),
    );
    expect(
      AutoBackupPolicy.initialDelayFor(overdue, now: now),
      AutoBackupPolicy.remainingDelayFloor,
    );
  });

  test('FGS uses status notification id and DETACH; cancels legacy FGS id', () {
    final fgs = File(
      '${_repoRoot().path}/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupForegroundService.kt',
    ).readAsStringSync();
    expect(fgs, contains('STATUS_NOTIFICATION_ID'));
    expect(fgs, contains('STOP_FOREGROUND_DETACH'));
    expect(fgs, contains('inProgressCopy'));
    expect(fgs, isNot(contains('FGS_NOTIFICATION_ID')));

    final channels = File(
      '${_repoRoot().path}/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupChannels.kt',
    ).readAsStringSync();
    expect(channels, contains('STATUS_NOTIFICATION_ID = 0x00ABAC01'));
    expect(channels, contains('LEGACY_FGS_NOTIFICATION_ID = 0x00ABAC03'));
    expect(channels, contains('cancelLegacyNotificationIds'));
  });

  test('runner does not double-notify success after queue drain', () {
    final source = File(
      '${_repoRoot().path}/lib/application/auto_backup/auto_backup_runner.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('_runQueueDrainCore already posted the terminal notification'),
    );
    // The pending-queue branch must not call notifyUseCase after drain.
    final pendingBlockStart = source.indexOf('if (pendingQueue.isNotEmpty)');
    final sessionBlockStart = source.indexOf('ensureHeadlessDriveSession');
    expect(pendingBlockStart, greaterThan(0));
    expect(sessionBlockStart, greaterThan(pendingBlockStart));
    final pendingBlock = source.substring(pendingBlockStart, sessionBlockStart);
    expect(pendingBlock, isNot(contains('notifyUseCase')));
  });

  test('native Doze-piercing components exist', () {
    final root = _repoRoot().path;
    expect(
      File(
        '$root/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupAlarmScheduler.kt',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupAlarmReceiver.kt',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupBootReceiver.kt',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/packages/backup_notifier/android/src/main/kotlin/com/akrmcodes/daftar/backup_notifier/AutoBackupForegroundService.kt',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/lib/application/auto_backup/auto_backup_service_entrypoint.dart',
      ).existsSync(),
      isTrue,
    );
    final manifest = File(
      '$root/packages/backup_notifier/android/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('AutoBackupAlarmReceiver'));
    expect(manifest, contains('AutoBackupBootReceiver'));
    expect(manifest, contains('AutoBackupForegroundService'));
    expect(manifest, contains('foregroundServiceType="dataSync"'));
  });
}
