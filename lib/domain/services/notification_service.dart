/// Contract for the app's local notification service.
abstract class NotificationService {
  /// Initializes the platform notification plugin.
  Future<void> init();

  /// Requests notification permissions on supported platforms.
  Future<bool> requestPermissions();

  /// Shows a local notification with an optional payload.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool isUrgent = false,
    String? payload,
  });
}
