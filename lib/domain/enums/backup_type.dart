/// Identifies the storage destination for a backup file.
///
/// - [local]: Stored on the device's local filesystem.
/// - [cloud]: Uploaded to Supabase Storage (encrypted).
/// - [googleDrive]: Encrypted backup mirrored to Google Drive `appDataFolder`.
enum BackupType {
  /// Backup stored locally on the device.
  local,

  /// Backup uploaded to cloud storage (Supabase).
  cloud,

  /// Backup uploaded to Google Drive app data folder.
  googleDrive,
}
