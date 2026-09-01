import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/mappers/backup_queue_mapper.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/repositories/backup_queue_repository.dart';

/// Drift implementation of [BackupQueueRepository].
class BackupQueueRepositoryImpl implements BackupQueueRepository {
  const BackupQueueRepositoryImpl({required BackupQueueLocalDs localDs})
      : _localDs = localDs;

  final BackupQueueLocalDs _localDs;

  @override
  Future<List<BackupQueueItem>> getPendingRetryable() async {
    final rows = await _localDs.getPendingRetryable();
    return rows.map((r) => r.toDomain()).toList(growable: false);
  }

  @override
  Future<void> insertItem(BackupQueueItem item) => _localDs.insertItem(item);

  @override
  Future<void> updateItem(BackupQueueItem item) => _localDs.updateItem(item);

  @override
  Future<void> deleteItem(String id) => _localDs.deleteItem(id);

  @override
  Future<bool> anyNeedsReauth() => _localDs.anyNeedsReauth();
}
