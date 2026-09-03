/// Values embedded in Google Drive `appProperties` and backup metadata.
///
/// Keep [schemaVersion] aligned with `DbConstants.schemaVersion` in
/// `lib/core/constants/db_constants.dart` whenever a Drift migration ships.
abstract final class DriveBackupConstants {
  /// Human-readable app release (mirror `pubspec.yaml` version).
  static const String appVersionLabel = '0.1.0+1';

  /// Drift schema generation / migration version at backup creation time.
  static const int schemaVersion = 26;

  /// Maximum `.daftar` files retained in Drive `appDataFolder`.
  ///
  /// After each successful upload, older files beyond this cap are deleted
  /// so duplicate/historical uploads cannot exhaust quota unnoticed.
  static const int maxRetainedDriveBackups = 400;

  /// How many cloud backups to show inline on the backup settings screen.
  ///
  /// The full catalog is available from **Restore from Drive**.
  static const int cloudBackupsInlinePreviewLimit = 10;
}
