/// Channel and notification id constants for auto-backup alerts.
///
/// IDs must match Kotlin `AutoBackupChannels` (`_v2` suffix).
/// A single status id is used for the whole run so in-progress → outcome
/// replaces in place (no dual tray / English flash).
abstract final class BackupNotificationIds {
  static const String alertsChannelId = 'daftar_auto_backup_v2';
  static const String urgentAlertsChannelId = 'daftar_auto_backup_urgent_v2';

  /// Sole notification id for FGS + Dart in-progress and outcome.
  static const int statusNotificationId = 0x00ABAC01;

  /// Alias used by dismiss / in-progress paths.
  static const int inProgressNotificationId = statusNotificationId;

  /// @Deprecated Prefer [statusNotificationId]; kept for docs/tests clarity.
  static const int outcomeNotificationId = statusNotificationId;

  /// Legacy separate FGS id — cancelled on ensureReady.
  static const int legacyForegroundServiceNotificationId = 0x00ABAC03;
}
