import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart';
import 'package:daftar/data/repositories/backup_repository_impl.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupRepositoryImpl Drive helpers', () {
    late Directory tempDir;
    late AppDatabase database;
    late BackupRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('daftar_backup_test_');
      database = AppDatabase(NativeDatabase.memory());
      repository = BackupRepositoryImpl(
        backupLocalDs: BackupLocalDs(
          database,
          documentsDirectoryResolver: () async => tempDir,
        ),
      );
    });

    tearDown(() async {
      await database.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('buildSnapshotFromEncryptedBackupFile reads checksum and size', () async {
      final file = File('${tempDir.path}/queued.daftar');
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      await file.writeAsBytes(bytes);
      final expectedChecksum = sha256.convert(bytes).toString();

      final result = await repository.buildSnapshotFromEncryptedBackupFile(
        file.path,
      );

      final snapshot = result.getRight().toNullable();
      expect(snapshot, isA<EncryptedLocalBackupSnapshot>());
      expect(snapshot?.filePath, file.path);
      expect(snapshot?.sizeBytes, bytes.length);
      expect(snapshot?.checksum, expectedChecksum);
    });

    test('insertGoogleDriveBackupRecord persists googleDriveFileId', () async {
      final snapshot = EncryptedLocalBackupSnapshot(
        filePath: '${tempDir.path}/drive.daftar',
        sizeBytes: 128,
        checksum: 'checksum-abc',
        createdAtUtc: DateTime.utc(2026, 6, 8),
      );
      await File(snapshot.filePath).writeAsBytes(const [9, 9, 9]);

      final result = await repository.insertGoogleDriveBackupRecord(
        snapshot: snapshot,
        googleDriveFileId: 'drive-file-123',
      );

      final metadata = result.getRight().toNullable();
      expect(metadata?.type, BackupType.googleDrive);
      expect(metadata?.googleDriveFileId, 'drive-file-123');
      expect(metadata?.checksum, snapshot.checksum);
    });

    test('buildSnapshotFromEncryptedBackupFile fails when file missing', () async {
      final result = await repository.buildSnapshotFromEncryptedBackupFile(
        '${tempDir.path}/missing.daftar',
      );

      final failure = result.getLeft().toNullable();
      expect(failure, isA<StorageFailure>());
      expect(failure?.code, 'queue_backup_missing');
    });
  });
}
