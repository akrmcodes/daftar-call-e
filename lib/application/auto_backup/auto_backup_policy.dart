import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/enums/drive_auto_backup_interval.dart';

/// Spacing policy for Android auto-backup alarm + WorkManager safety net.
abstract final class AutoBackupPolicy {
  static const double minElapsedFraction = 0.8;
  static const Duration remainingDelayFloor = Duration(seconds: 30);
  static const Duration firstRunDelay = Duration(minutes: 1);

  static Duration intervalFor(AppSettings settings) {
    final interval = DriveAutoBackupInterval.fromStorage(
      settings.driveAutoBackupInterval,
    );
    return switch (interval) {
      DriveAutoBackupInterval.daily => const Duration(hours: 24),
      DriveAutoBackupInterval.weekly => const Duration(days: 7),
    };
  }

  /// Due-time based delay until the next eligible backup.
  ///
  /// - No prior backup → short [firstRunDelay] so enabling the feature gives
  ///   immediate visible feedback on any interval.
  /// - Otherwise → `max(lastBackupAt + interval - now, floor)`.
  ///
  /// Never returns a flat 1-hour reset that starves the schedule on cold start.
  static Duration initialDelayFor(
    AppSettings settings, {
    DateTime? now,
  }) {
    final interval = intervalFor(settings);
    final last = settings.lastBackupAt;
    final clock = now ?? DateTime.now().toUtc();
    if (last == null) {
      return firstRunDelay;
    }
    final dueAt = last.toUtc().add(interval);
    final remaining = dueAt.difference(clock);
    if (remaining <= Duration.zero) {
      return remainingDelayFloor;
    }
    return remaining < remainingDelayFloor ? remainingDelayFloor : remaining;
  }

  static Duration minElapsed(Duration interval) {
    return Duration(
      microseconds: (interval.inMicroseconds * minElapsedFraction).round(),
    );
  }

  /// Whether another auto upload should be skipped (backup still fresh).
  static bool shouldSkip({
    required AppSettings settings,
    required Duration interval,
    DateTime? now,
  }) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return false;
    }
    final clock = now ?? DateTime.now().toUtc();
    return clock.difference(last.toUtc()) < minElapsed(interval);
  }

  /// Remaining delay until the 80% cadence window elapses.
  static Duration delayUntilEligible({
    required AppSettings settings,
    required Duration interval,
    DateTime? now,
  }) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return remainingDelayFloor;
    }
    final clock = now ?? DateTime.now().toUtc();
    final remaining = minElapsed(interval) - clock.difference(last.toUtc());
    if (remaining <= Duration.zero) {
      return remainingDelayFloor;
    }
    return remaining < remainingDelayFloor ? remainingDelayFloor : remaining;
  }

  /// Whether last backup is older than the cadence window (catch-up).
  static bool isStale({
    required AppSettings settings,
    required Duration interval,
    DateTime? now,
  }) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return true;
    }
    final clock = now ?? DateTime.now().toUtc();
    return clock.difference(last.toUtc()) >= minElapsed(interval);
  }

  static bool shouldForceCatchUp({
    required AppSettings settings,
    required bool scheduleOverdue,
    DateTime? now,
  }) {
    if (!settings.driveAutoBackupEnabled) {
      return false;
    }
    final id = settings.googleAccountId;
    if (id == null || id.isEmpty) {
      return false;
    }
    if (scheduleOverdue) {
      return true;
    }
    return isStale(
      settings: settings,
      interval: intervalFor(settings),
      now: now,
    );
  }

  static Duration transientBackoffFor(Duration interval) {
    final sixth = Duration(microseconds: interval.inMicroseconds ~/ 6);
    if (sixth <= Duration.zero) {
      return const Duration(minutes: 5);
    }
    const cap = Duration(minutes: 5);
    return sixth < cap ? sixth : cap;
  }

  /// Clamps [interval] to Android's WorkManager periodic minimum (15 min).
  static Duration periodicSafetyNetInterval(Duration interval) {
    const min = Duration(minutes: 15);
    return interval < min ? min : interval;
  }
}
