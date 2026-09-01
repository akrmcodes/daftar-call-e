import 'dart:io';
import 'dart:typed_data';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

class _StoredRemoteBackup {
  const _StoredRemoteBackup({
    required this.id,
    required this.name,
    required this.bytes,
    required this.metadata,
    required this.modifiedTimeUtc,
  });

  final String id;
  final String name;
  final Uint8List bytes;
  final Map<String, String> metadata;
  final DateTime modifiedTimeUtc;

  GoogleDriveRemoteBackupItem toRemoteItem() {
    return GoogleDriveRemoteBackupItem(
      id: id,
      name: name,
      sizeBytes: bytes.length,
      modifiedTimeUtc: modifiedTimeUtc,
      appProperties: Map<String, String>.from(metadata),
    );
  }
}

/// In-memory Google Drive remote repository for hermetic integration tests.
class FakeDriveBackupRemoteRepository
    implements GoogleDriveBackupRemoteRepository {
  FakeDriveBackupRemoteRepository();

  final Map<String, _StoredRemoteBackup> _store = {};
  final List<String> deletedTempPaths = <String>[];
  int uploadCalls = 0;
  int listCalls = 0;
  int fetchCalls = 0;
  int downloadCalls = 0;
  int deleteCalls = 0;
  int _sequence = 0;

  String? lastUploadedFileId;
  String? lastUploadedFilePath;
  Map<String, String>? lastUploadedMetadata;

  Failure? _nextUploadFailure;

  // Test chaos hook — method name reads better than a setter at call sites.
  // ignore: use_setters_to_change_properties
  void failNextUpload(Failure failure) {
    _nextUploadFailure = failure;
  }

  void seedRemoteBackup({
    required String fileId,
    required Uint8List bytes,
    required Map<String, String> metadata,
    String name = 'seeded.daftar',
    DateTime? modifiedTimeUtc,
  }) {
    _store[fileId] = _StoredRemoteBackup(
      id: fileId,
      name: name,
      bytes: bytes,
      metadata: Map<String, String>.from(metadata),
      modifiedTimeUtc: modifiedTimeUtc ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<Either<Failure, GoogleDriveUploadResult>> uploadEncryptedBackup({
    required String absoluteFilePath,
    required Map<String, String> metadata,
  }) async {
    uploadCalls += 1;
    final failure = _nextUploadFailure;
    if (failure != null) {
      _nextUploadFailure = null;
      return Left(failure);
    }

    final bytes = await File(absoluteFilePath).readAsBytes();
    final fileId = 'drive-file-${++_sequence}';
    _store[fileId] = _StoredRemoteBackup(
      id: fileId,
      name: p.basename(absoluteFilePath),
      bytes: bytes,
      metadata: Map<String, String>.from(metadata),
      modifiedTimeUtc: DateTime.now().toUtc(),
    );
    lastUploadedFileId = fileId;
    lastUploadedFilePath = absoluteFilePath;
    lastUploadedMetadata = Map<String, String>.from(metadata);
    return Right(
      GoogleDriveUploadResult(
        fileId: fileId,
        name: p.basename(absoluteFilePath),
        sizeBytes: bytes.length,
      ),
    );
  }

  @override
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>>
      listRemoteBackups() async {
    listCalls += 1;
    final items = _store.values.map((entry) => entry.toRemoteItem()).toList()
      ..sort(
        (left, right) =>
            right.modifiedTimeUtc!.compareTo(left.modifiedTimeUtc!),
      );
    return Right(items);
  }

  @override
  Future<Either<Failure, GoogleDriveRemoteBackupItem>> fetchRemoteBackupById(
    String fileId,
  ) async {
    fetchCalls += 1;
    final entry = _store[fileId];
    if (entry == null) {
      return const Left(
        ValidationFailure(
          'Remote backup not found.',
          code: 'remote_backup_not_found',
        ),
      );
    }
    return Right(entry.toRemoteItem());
  }

  @override
  Future<Either<Failure, Unit>> downloadBackupToFile({
    required String fileId,
    required String destinationPath,
  }) async {
    downloadCalls += 1;
    final entry = _store[fileId];
    if (entry == null) {
      return const Left(
        ValidationFailure(
          'Remote backup not found.',
          code: 'remote_backup_not_found',
        ),
      );
    }

    final destinationFile = File(destinationPath);
    await destinationFile.parent.create(recursive: true);
    await destinationFile.writeAsBytes(entry.bytes, flush: true);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, String>> downloadBackupToTemporaryFile(
    String fileId,
  ) async {
    final destinationPath = p.join(
      Directory.systemTemp.path,
      'daftar_drive_restore_${DateTime.now().microsecondsSinceEpoch}_$fileId.daftar',
    );
    final result = await downloadBackupToFile(
      fileId: fileId,
      destinationPath: destinationPath,
    );
    if (result case Left(value: final failure)) {
      return Left(failure);
    }
    return Right(destinationPath);
  }

  @override
  Future<Either<Failure, Unit>> deleteIfPresent(String absolutePath) async {
    deleteCalls += 1;
    deletedTempPaths.add(absolutePath);
    try {
      final file = File(absolutePath);
      if (file.existsSync()) {
        await file.delete();
      }
      return const Right(unit);
    } on Object catch (error) {
      return Left(
        StorageFailure(
          'Failed to delete temporary backup file: $error',
          code: 'drive_temp_delete_error',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteRemoteBackup(String fileId) async {
    deleteCalls += 1;
    final removed = _store.remove(fileId);
    if (removed == null) {
      return const Left(
        ValidationFailure(
          'Remote backup not found.',
          code: 'remote_backup_not_found',
        ),
      );
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> pruneOldRemoteBackups({
    required int keepNewest,
  }) async {
    final listed = await listRemoteBackups();
    return listed.fold(
      Left.new,
      (items) async {
        if (items.length <= keepNewest) {
          return const Right(unit);
        }
        for (final item in items.skip(keepNewest)) {
          await deleteRemoteBackup(item.id);
        }
        return const Right(unit);
      },
    );
  }
}
