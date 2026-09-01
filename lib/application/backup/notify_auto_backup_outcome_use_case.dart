import 'package:daftar/domain/constants/backup_notification_ids.dart';
import 'package:daftar/domain/enums/auto_backup_notification_event.dart';
import 'package:daftar/domain/services/backup_notification_port.dart';
import 'package:daftar/domain/services/backup_notification_strings_resolver.dart';

/// Posts localized auto-backup notifications for headless and foreground paths.
///
/// Maps [AutoBackupNotificationEvent] to channel and localized copy.
/// All events share [BackupNotificationIds.statusNotificationId] so the tray
/// shows one notification that updates in place (in-progress → outcome).
class NotifyAutoBackupOutcomeUseCase {
  const NotifyAutoBackupOutcomeUseCase(
    this._port,
    this._strings,
  );

  final BackupNotificationPort _port;
  final BackupNotificationStringsResolver _strings;

  /// Shows the notification for [event] in the given [locale] (`ar` or `en`).
  Future<void> call(
    AutoBackupNotificationEvent event, {
    required String locale,
  }) async {
    await _port.ensureReady();

    final copy = _strings.resolve(event, locale);
    final isUrgent = event != AutoBackupNotificationEvent.inProgress;
    final channelId = isUrgent
        ? BackupNotificationIds.urgentAlertsChannelId
        : BackupNotificationIds.alertsChannelId;

    await _port.show(
      id: BackupNotificationIds.statusNotificationId,
      channelId: channelId,
      title: copy.title,
      body: copy.body,
      ongoing: event == AutoBackupNotificationEvent.inProgress,
      urgent: isUrgent,
    );
  }
}
