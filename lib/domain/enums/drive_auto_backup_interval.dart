/// Cadence for scheduled Google Drive auto-backup.
enum DriveAutoBackupInterval {
  /// Run approximately once per day.
  daily('daily'),

  /// Run approximately once per week.
  weekly('weekly');

  const DriveAutoBackupInterval(this.storageValue);

  /// Persisted value in app settings (`driveAutoBackupInterval` column).
  final String storageValue;

  /// Parses a stored interval or returns [daily] when unknown.
  ///
  /// Legacy test cadence `every_30_min` maps to [daily].
  static DriveAutoBackupInterval fromStorage(String? raw) {
    return switch (raw) {
      'weekly' => DriveAutoBackupInterval.weekly,
      // Legacy test cadence — treat as daily.
      'every_30_min' => DriveAutoBackupInterval.daily,
      _ => DriveAutoBackupInterval.daily,
    };
  }
}
