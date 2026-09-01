import 'package:daftar/domain/enums/auto_backup_notification_event.dart';

/// Localized title/body pair for a backup notification.
typedef BackupNotificationCopy = ({String title, String body});

/// Resolves localized auto-backup notification copy for a locale code.
abstract class BackupNotificationStringsResolver {
  /// Returns title and body for [event] in the given [locale] (`ar` or `en`).
  BackupNotificationCopy resolve(
    AutoBackupNotificationEvent event,
    String locale,
  );
}
