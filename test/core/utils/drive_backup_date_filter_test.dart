import 'package:daftar/core/utils/drive_backup_date_filter.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final backups = [
    GoogleDriveRemoteBackupItem(
      id: '1',
      name: 'Daftar_Backup_20240801_120000.daftar',
      modifiedTimeUtc: DateTime.utc(2024, 8, 1, 14, 30),
    ),
    GoogleDriveRemoteBackupItem(
      id: '2',
      name: 'Daftar_Backup_20240801_180000.daftar',
      modifiedTimeUtc: DateTime.utc(2024, 8, 1, 18),
    ),
    GoogleDriveRemoteBackupItem(
      id: '3',
      name: 'Daftar_Backup_20241225_090000.daftar',
      modifiedTimeUtc: DateTime.utc(2024, 12, 25, 9),
    ),
  ];

  group('filterDriveBackupsByDay', () {
    test('returns all items when day is null', () {
      expect(filterDriveBackupsByDay(backups, null), backups);
    });

    test('keeps backups on the selected local day', () {
      final day = DateTime(2024, 8);
      final result = filterDriveBackupsByDay(backups, day);
      expect(result, [backups[0], backups[1]]);
    });

    test('returns empty when no backups match the day', () {
      final day = DateTime(2023);
      expect(filterDriveBackupsByDay(backups, day), isEmpty);
    });
  });

  group('groupDriveBackupsByDay', () {
    test('groups backups newest day first', () {
      final groups = groupDriveBackupsByDay(backups);
      expect(groups, hasLength(2));
      expect(groups.first.items, [backups[2]]);
      expect(groups.last.items, [backups[0], backups[1]]);
    });
  });

  group('oldestBackupDay', () {
    test('returns the earliest known backup day', () {
      expect(
        oldestBackupDay(backups),
        DateTime(2024, 8),
      );
    });
  });
}
