import 'package:daftar/domain/enums/drive_auto_backup_interval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriveAutoBackupInterval', () {
    test('fromStorage maps legacy every_30_min to daily', () {
      expect(
        DriveAutoBackupInterval.fromStorage('every_30_min'),
        DriveAutoBackupInterval.daily,
      );
    });

    test('fromStorage maps known daily and weekly values', () {
      expect(
        DriveAutoBackupInterval.fromStorage('daily'),
        DriveAutoBackupInterval.daily,
      );
      expect(
        DriveAutoBackupInterval.fromStorage('weekly'),
        DriveAutoBackupInterval.weekly,
      );
    });

    test('fromStorage defaults to daily for null or unknown', () {
      expect(
        DriveAutoBackupInterval.fromStorage(null),
        DriveAutoBackupInterval.daily,
      );
      expect(
        DriveAutoBackupInterval.fromStorage('bogus'),
        DriveAutoBackupInterval.daily,
      );
    });

    test('storageValue round-trips for every interval', () {
      for (final interval in DriveAutoBackupInterval.values) {
        expect(
          DriveAutoBackupInterval.fromStorage(interval.storageValue),
          interval,
        );
      }
    });
  });
}
