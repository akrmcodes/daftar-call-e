import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_queue_item.freezed.dart';

/// Local queue row for a deferred Google Drive backup upload.
@freezed
abstract class BackupQueueItem with _$BackupQueueItem {
  const factory BackupQueueItem({
    required String id,
    required BackupQueueStatus status,
    String? backupMetadataId,
    String? pendingBackupFilePath,
    DateTime? lastBackupAttemptAt,
    @Default(0) int backupRetryCount,
    DateTime? nextRetryAt,
  }) = _BackupQueueItem;
}
