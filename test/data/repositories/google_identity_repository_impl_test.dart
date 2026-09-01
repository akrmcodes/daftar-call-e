import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/repositories/google_identity_repository_impl.dart';
import 'package:daftar/domain/entities/backup_queue_item.dart';
import 'package:daftar/domain/enums/backup_queue_status.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  group('GoogleIdentityRepositoryImpl', () {
    late AppDatabase database;
    late BackupLocalDs backupLocalDs;
    late BackupQueueLocalDs backupQueueLocalDs;
    late AuditLogLocalDataSource auditLogLocalDataSource;
    late GoogleIdentityRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      backupLocalDs = BackupLocalDs(database);
      backupQueueLocalDs = BackupQueueLocalDs(database);
      auditLogLocalDataSource = AuditLogLocalDataSource(database);
      repository = GoogleIdentityRepositoryImpl(
        database: database,
        backupLocalDs: backupLocalDs,
        backupQueueLocalDs: backupQueueLocalDs,
        auditLogLocalDataSource: auditLogLocalDataSource,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('purges Drive file ids, clears queue, and appends audit log', () async {
      await database.into(database.backupMetadatas).insert(
            BackupMetadatasCompanion.insert(
              id: 'backup-1',
              filePath: '/tmp/backup.daftar',
              sizeBytes: 1024,
              type: BackupType.googleDrive,
              checksum: 'abc',
              googleDriveFileId: const Value('drive-file-1'),
            ),
          );
      await backupQueueLocalDs.insertItem(
        const BackupQueueItem(
          id: 'queue-1',
          status: BackupQueueStatus.queued,
          pendingBackupFilePath: '/tmp/pending.daftar',
        ),
      );

      final result = await repository.purgeDriveIdentityOnAccountSwitch(
        oldEmail: 'old@example.com',
        newEmail: 'new@example.com',
        newAccountId: 'google-new',
      );

      expect(result, isA<Right<Failure, Unit>>());

      final backupRow = await (database.select(database.backupMetadatas)
            ..where((t) => t.id.equals('backup-1')))
          .getSingle();
      expect(backupRow.googleDriveFileId, isNull);

      final queueRows = await database.select(database.driveBackupQueueRows).get();
      expect(queueRows, isEmpty);

      final auditRows = await database.select(database.auditLogs).get();
      expect(auditRows, hasLength(1));
      expect(auditRows.single.entityType, 'google_account');
      expect(auditRows.single.action, 'ACCOUNT_SWITCH');
      expect(auditRows.single.entityId, 'google-new');
      expect(auditRows.single.payload, contains('old@example.com'));
      expect(auditRows.single.payload, contains('new@example.com'));
    });
  });
}
