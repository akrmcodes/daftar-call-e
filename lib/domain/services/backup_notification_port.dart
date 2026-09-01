/// Contract for posting auto-backup local notifications.
abstract class BackupNotificationPort {
  /// Ensures the native notification bridge is ready (Android channels).
  Future<void> ensureReady();

  /// Shows a notification with the given localized copy.
  Future<void> show({
    required int id,
    required String channelId,
    required String title,
    required String body,
    bool ongoing = false,
    bool urgent = false,
  });

  /// Dismisses the in-progress notification.
  Future<void> dismissInProgress();
}
