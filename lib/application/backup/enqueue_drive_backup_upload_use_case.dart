import 'package:daftar/application/auto_backup/auto_backup_scheduler.dart';
import 'package:daftar/core/services/pending_cloud_sync_store.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';

/// Persists a failed Drive upload for later resume when connectivity returns.
class EnqueueDriveBackupUploadUseCase {
  /// Creates the use case with the given backup queue repository.
  const EnqueueDriveBackupUploadUseCase(this._backupQueueRepository);

  final BackupQueueRepository _backupQueueRepository;

  /// Inserts or updates queue state for [encryptedBackupPath].
  Future<void> call({
    required String encryptedBackupPath,
    String? backupMetadataId,
  }) async {
    final path = encryptedBackupPath.trim();
    if (path.isEmpty) {
      return;
    }

    final pending = await _backupQueueRepository.getPendingRetryable();
    final existing =
        pending.where((item) => item.pendingBackupFilePath == path);
    if (existing.isEmpty) {
      await _backupQueueRepository.insertItem(
        BackupQueueItem(
          id: UuidUtil.generate(),
          status: BackupQueueStatus.queued,
          backupMetadataId: backupMetadataId,
          pendingBackupFilePath: path,
        ),
      );
    }

    await PendingCloudSyncStore.setPending(value: true);
    await AutoBackupScheduler.scheduleQueueDrain();
  }
}
