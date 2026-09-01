import 'package:freezed_annotation/freezed_annotation.dart';

part 'google_drive_remote_backup_item.freezed.dart';

/// Summary of a remote `.daftar` backup in Google Drive `appDataFolder`.
@freezed
abstract class GoogleDriveRemoteBackupItem with _$GoogleDriveRemoteBackupItem {
  const factory GoogleDriveRemoteBackupItem({
    required String id,
    required String name,
    int? sizeBytes,
    DateTime? modifiedTimeUtc,
    Map<String, String>? appProperties,
  }) = _GoogleDriveRemoteBackupItem;
}
