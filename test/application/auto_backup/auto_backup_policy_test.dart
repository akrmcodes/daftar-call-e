import 'package:daftar/application/auto_backup/auto_backup_policy.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoBackupPolicy', () {
    test('delayUntilEligible returns remaining after recent manual backup', () {
      final now = DateTime.utc(2026, 7, 28, 12);
      final settings = AppSettings(
        lastBackupAt: now.subtract(const Duration(minutes: 6)),
      );
      expect(
        AutoBackupPolicy.delayUntilEligible(
          settings: settings,
          interval: const Duration(minutes: 30),
          now: now,
        ),
        const Duration(minutes: 18),
      );
    });

    test('shouldSkip within 80% window', () {
      final now = DateTime.utc(2026, 7, 28, 12);
      final settings = AppSettings(
        lastBackupAt: now.subtract(const Duration(minutes: 20)),
      );
      expect(
        AutoBackupPolicy.shouldSkip(
          settings: settings,
          interval: const Duration(minutes: 30),
          now: now,
        ),
        isTrue,
      );
    });

    test('shouldForceCatchUp when stale', () {
      final now = DateTime.utc(2026, 7, 28, 12);
      final settings = AppSettings(
        driveAutoBackupEnabled: true,
        googleAccountId: 'acct',
        lastBackupAt: now.subtract(const Duration(hours: 20)),
      );
      expect(
        AutoBackupPolicy.shouldForceCatchUp(
          settings: settings,
          scheduleOverdue: false,
          now: now,
        ),
        isTrue,
      );
    });

    test('transientBackoff capped at 5 minutes', () {
      expect(
        AutoBackupPolicy.transientBackoffFor(const Duration(hours: 24)),
        const Duration(minutes: 5),
      );
    });

    test('initialDelayFor uses remaining cadence not flat hour', () {
      final now = DateTime.utc(2026, 8, 9, 12);
      final settings = AppSettings(
        lastBackupAt: now.subtract(const Duration(hours: 20)),
      );
      expect(
        AutoBackupPolicy.initialDelayFor(settings, now: now),
        const Duration(hours: 4),
      );
    });

    test('initialDelayFor first run is one minute', () {
      expect(
        AutoBackupPolicy.initialDelayFor(
          const AppSettings(driveAutoBackupInterval: 'weekly'),
          now: DateTime.utc(2026, 8, 9),
        ),
        const Duration(minutes: 1),
      );
    });

    test('periodicSafetyNetInterval clamps below 15 minutes', () {
      expect(
        AutoBackupPolicy.periodicSafetyNetInterval(const Duration(minutes: 5)),
        const Duration(minutes: 15),
      );
      expect(
        AutoBackupPolicy.periodicSafetyNetInterval(const Duration(hours: 24)),
        const Duration(hours: 24),
      );
    });
  });
}
