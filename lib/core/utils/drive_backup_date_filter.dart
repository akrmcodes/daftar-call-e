import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';

/// Local calendar date for a remote backup, or null when unknown.
DateTime? backupLocalDate(GoogleDriveRemoteBackupItem item) {
  final modified = item.modifiedTimeUtc?.toLocal();
  if (modified == null) {
    return null;
  }
  return DateTime(modified.year, modified.month, modified.day);
}

/// Whether [a] and [b] fall on the same local calendar day.
bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Keeps backups that match [day] when non-null; otherwise returns [items].
List<GoogleDriveRemoteBackupItem> filterDriveBackupsByDay(
  List<GoogleDriveRemoteBackupItem> items,
  DateTime? day,
) {
  if (day == null) {
    return items;
  }
  final target = DateTime(day.year, day.month, day.day);
  return items
      .where((item) {
        final local = backupLocalDate(item);
        return local != null && isSameCalendarDay(local, target);
      })
      .toList(growable: false);
}

/// Newest-first groups keyed by local calendar day.
class DriveBackupDayGroup {
  const DriveBackupDayGroup({
    required this.day,
    required this.items,
  });

  final DateTime day;
  final List<GoogleDriveRemoteBackupItem> items;
}

List<DriveBackupDayGroup> groupDriveBackupsByDay(
  List<GoogleDriveRemoteBackupItem> items,
) {
  final grouped = <DateTime, List<GoogleDriveRemoteBackupItem>>{};
  for (final item in items) {
    final day = backupLocalDate(item);
    if (day == null) {
      continue;
    }
    grouped.putIfAbsent(day, () => <GoogleDriveRemoteBackupItem>[]).add(item);
  }

  final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return days
      .map(
        (day) => DriveBackupDayGroup(
          day: day,
          items: grouped[day]!,
        ),
      )
      .toList(growable: false);
}

/// Oldest known backup day in [items], for date-picker bounds.
DateTime? oldestBackupDay(List<GoogleDriveRemoteBackupItem> items) {
  DateTime? oldest;
  for (final item in items) {
    final day = backupLocalDate(item);
    if (day == null) {
      continue;
    }
    if (oldest == null || day.isBefore(oldest)) {
      oldest = day;
    }
  }
  return oldest;
}
