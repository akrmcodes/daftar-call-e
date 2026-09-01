import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/repositories/backup_queue_repository_impl.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupQueueRepositoryImpl', () {
    late AppDatabase database;
    late BackupQueueRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      repository = BackupQueueRepositoryImpl(
        localDs: BackupQueueLocalDs(database),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('inserts and returns pending retryable rows', () async {
      await repository.insertItem(
        const BackupQueueItem(
          id: 'queue-1',
          status: BackupQueueStatus.queued,
          pendingBackupFilePath: '/tmp/pending.daftar',
        ),
      );

      final pending = await repository.getPendingRetryable();

      expect(pending, hasLength(1));
      expect(pending.single.id, 'queue-1');
    });

    test('reports needsReauth rows', () async {
      await repository.insertItem(
        const BackupQueueItem(
          id: 'queue-2',
          status: BackupQueueStatus.needsReauth,
        ),
      );

      expect(await repository.anyNeedsReauth(), isTrue);
    });

    test('deletes item by id', () async {
      await repository.insertItem(
        const BackupQueueItem(
          id: 'queue-3',
          status: BackupQueueStatus.failed,
        ),
      );

      await repository.deleteItem('queue-3');

      expect(await repository.getPendingRetryable(), isEmpty);
    });
  });
}
