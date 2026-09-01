import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/encryption_util.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/mappers/backup_metadata_mapper.dart';
import 'package:daftar/domain/entities/backup_metadata.dart';
import 'package:daftar/domain/entities/encrypted_local_backup_snapshot.dart';
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:daftar/domain/repositories/backup_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed, AES-256-GCM implementation of [BackupRepository].
///
/// Encryption uses an app-bound key delivered via `envied` build-time
/// obfuscation. The key is resolved internally by [EncryptionUtil] based
/// on the backup format version byte — the repository never handles raw
/// key material. This makes the entire backup pipeline **stateless**:
/// no `flutter_secure_storage` dependency, no key that can be lost on
/// uninstall or device migration.
///
/// Encryption and decryption are offloaded to a Dart isolate to
/// avoid blocking the UI thread on large database files.
///
/// Cloud backup methods (uploadCloud, downloadCloud) are stubbed and
/// will be implemented in Stage 4.5.
class BackupRepositoryImpl implements BackupRepository {
  /// Creates a [BackupRepositoryImpl].
  ///
  /// [backupLocalDs] handles all file I/O and DB metadata writes.
  const BackupRepositoryImpl({
    required BackupLocalDs backupLocalDs,
  }) : _ds = backupLocalDs;

  final BackupLocalDs _ds;

  // ── Public API ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, BackupMetadata>> createLocal() async {
    try {
      final snapshot = await _createEncryptedSnapshotCore();
      final companion = buildBackupCompanion(
        id: UuidUtil.generate(),
        filePath: snapshot.filePath,
        sizeBytes: snapshot.sizeBytes,
        createdAt: snapshot.createdAtUtc,
        type: BackupType.local,
        checksum: snapshot.checksum,
      );
      final row = await _ds.insertMetadata(companion);
      return Right(row.toDomain());
    } on FileSystemException catch (e) {
      return Left(
        StorageFailure('Backup file I/O failed: ${e.message}', code: 'backup_io_error'),
      );
    } on Object catch (e) {
      return Left(
        StorageFailure('Backup creation failed: $e', code: 'backup_error'),
      );
    }
  }

  @override
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      createEncryptedBackupFileOnly() async {
    try {
      final snapshot = await _createEncryptedSnapshotCore();
      return Right(snapshot);
    } on FileSystemException catch (e) {
      return Left(
        StorageFailure('Backup file I/O failed: ${e.message}', code: 'backup_io_error'),
      );
    } on Object catch (e) {
      return Left(
        StorageFailure('Backup creation failed: $e', code: 'backup_error'),
      );
    }
  }

  @override
  Future<Either<Failure, BackupMetadata>> insertGoogleDriveBackupRecord({
    required EncryptedLocalBackupSnapshot snapshot,
    required String googleDriveFileId,
  }) async {
    try {
      final companion = buildBackupCompanion(
        id: UuidUtil.generate(),
        filePath: snapshot.filePath,
        sizeBytes: snapshot.sizeBytes,
        createdAt: snapshot.createdAtUtc,
        type: BackupType.googleDrive,
        checksum: snapshot.checksum,
        googleDriveFileId: googleDriveFileId,
      );
      final row = await _ds.insertMetadata(companion);
      return Right(row.toDomain());
    } on Object catch (e) {
      return Left(
        DatabaseFailure(
          'Failed to save Google Drive backup metadata: $e',
          code: 'drive_metadata_insert_error',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, EncryptedLocalBackupSnapshot>>
      buildSnapshotFromEncryptedBackupFile(String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (!file.existsSync()) {
        return const Left(
          StorageFailure(
            'Queued backup file was not found on disk.',
            code: 'queue_backup_missing',
          ),
        );
      }
      final (bytes, checksum) = await Isolate.run(() {
        final data = File(absolutePath).readAsBytesSync();
        final digest = sha256.convert(data).toString();
        return (data, digest);
      });
      final modified = file.statSync().modified.toUtc();
      return Right(
        EncryptedLocalBackupSnapshot(
          filePath: absolutePath,
          sizeBytes: bytes.length,
          checksum: checksum,
          createdAtUtc: modified,
        ),
      );
    } on FileSystemException catch (e) {
      return Left(
        StorageFailure(
          'Could not read queued backup file: ${e.message}',
          code: 'queue_backup_io_error',
        ),
      );
    } on Object catch (e) {
      return Left(
        StorageFailure(
          'Could not build snapshot from backup file: $e',
          code: 'queue_snapshot_error',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> restoreLocal(
    String filePath, {
    required String expectedChecksum,
  }) async {
    File? tempFile;
    try {
      final encryptedBytes = await _ds.readBackupFile(filePath);

      // Checksum validation is only performed when a pre-computed hash
      // was provided (i.e. restoring from the backup list). External
      // files picked via file_picker have no stored checksum — integrity
      // is still enforced by the GCM authentication tag during decryption.
      if (expectedChecksum.trim().isNotEmpty) {
        final computedChecksum = await Isolate.run(
          () => sha256.convert(encryptedBytes).toString(),
        );
        if (computedChecksum != expectedChecksum) {
          return const Left(
            ValidationFailure(
              'Checksum mismatch. The backup file is corrupted or has been tampered with.',
              code: 'restore_checksum_mismatch',
            ),
          );
        }
      }

      final decryptedBytes = await Isolate.run(
        () => EncryptionUtil.decryptBackup(encryptedBytes),
      );

      tempFile = await _ds.writeTempRestoreFile(decryptedBytes);

      // ── POINT OF NO RETURN ────────────────────────────────────────────

      // Close the active DB connection. Wrapped in try/catch to handle
      // fresh-install scenarios where the database may not be open yet.
      try {
        await _ds.closeDatabase();
      } on Object {
        // DB was never opened (fresh install) — safe to proceed.
      }

      await _ds.deleteWalAndShmFiles();

      // Ensure the destination directory exists (fresh install guard).
      final dbPath = await _ds.getDatabasePath();
      final dbDir = File(dbPath).parent;
      if (!dbDir.existsSync()) {
        dbDir.createSync(recursive: true);
      }

      await _ds.renameTempToDatabase(tempFile);

      return const Right(unit);
    } on FileSystemException catch (e) {
      await _cleanupTempFile(tempFile);
      return Left(
        StorageFailure(
          'Backup file I/O failed: ${e.message}',
          code: 'restore_io_error',
        ),
      );
    } on FormatException catch (e) {
      await _cleanupTempFile(tempFile);
      return Left(
        ValidationFailure(
          e.message,
          code: 'restore_invalid_format',
        ),
      );
    } on Object catch (e) {
      await _cleanupTempFile(tempFile);
      return Left(
        StorageFailure(
          'Backup restore failed: $e',
          code: 'restore_error',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, BackupMetadata>> uploadCloud() async {
    // Implemented in Stage 4.5 — UploadCloudBackupUseCase.
    return const Left(NetworkFailure('Cloud backup not yet implemented'));
  }

  @override
  Future<Either<Failure, Unit>> downloadCloud(String backupId) async {
    // Implemented in Stage 4.5 — DownloadCloudBackupUseCase.
    return const Left(NetworkFailure('Cloud restore not yet implemented'));
  }

  @override
  Future<Either<Failure, List<BackupMetadata>>> listBackups({
    BackupType? filterType,
  }) async {
    try {
      final rows = await _ds.getAllMetadata(filterType: filterType);
      return Right(rows.map((r) => r.toDomain()).toList(growable: false));
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to list backups: $e', code: 'list_backups_error'),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteBackup(String id) async {
    try {
      // Step 1: Fetch metadata to obtain the physical file path.
      final row = await _ds.getMetadataById(id);
      if (row == null) {
        return const Left(
          DatabaseFailure('Backup not found.', code: 'backup_not_found'),
        );
      }

      // Step 2: Delete the physical .daftar file from disk (best-effort).
      final file = File(row.filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      // Step 3: Remove the metadata record from the database.
      await _ds.deleteMetadata(id);

      return const Right(unit);
    } on FileSystemException catch (e) {
      return Left(
        StorageFailure('Failed to delete backup file: ${e.message}', code: 'delete_backup_io_error'),
      );
    } on Object catch (e) {
      return Left(
        DatabaseFailure('Failed to delete backup: $e', code: 'delete_backup_error'),
      );
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<EncryptedLocalBackupSnapshot> _createEncryptedSnapshotCore() async {
    await _ds.checkpointWal();
    final plainBytes = await _ds.readDatabaseBytes();
    final (encryptedBytes, checksum) = await Isolate.run(() {
      final encrypted = EncryptionUtil.encryptBackup(plainBytes);
      final digest = sha256.convert(encrypted).toString();
      return (encrypted, digest);
    });
    final timestamp = DateTime.now().toUtc();
    final filePath = await _ds.writeBackupFile(encryptedBytes, timestamp);
    return EncryptedLocalBackupSnapshot(
      filePath: filePath,
      sizeBytes: encryptedBytes.length,
      checksum: checksum,
      createdAtUtc: timestamp,
    );
  }

  /// Silently deletes the temp staging file on restore failure.
  ///
  /// Best-effort cleanup — if the delete itself fails, we swallow
  /// the error because the primary failure is more important.
  Future<void> _cleanupTempFile(File? tempFile) async {
    if (tempFile != null && tempFile.existsSync()) {
      try {
        await tempFile.delete();
      } on Object {
        // Intentionally swallowed — primary failure takes precedence.
      }
    }
  }
}
