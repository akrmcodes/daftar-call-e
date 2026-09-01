import 'dart:async';
import 'dart:io';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/remote/google_auth_ds.dart';
import 'package:daftar/data/datasources/remote/google_auth_exceptions.dart';
import 'package:daftar/data/datasources/remote/google_auth_failure_mapper.dart';
import 'package:daftar/data/datasources/remote/google_drive_backup_ds.dart';
import 'package:daftar/data/datasources/remote/google_drive_backup_exceptions.dart';
import 'package:daftar/domain/entities/google_drive_remote_backup_item.dart';
import 'package:daftar/domain/entities/google_drive_upload_result.dart';
import 'package:daftar/domain/repositories/google_drive_backup_remote_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// [GoogleDriveBackupRemoteRepository] backed by [GoogleAuthDs] and Drive v3.
class GoogleDriveBackupRemoteRepositoryImpl
    implements GoogleDriveBackupRemoteRepository {
  const GoogleDriveBackupRemoteRepositoryImpl({
    required GoogleAuthDs googleAuthDs,
  }) : _googleAuthDs = googleAuthDs;

  final GoogleAuthDs _googleAuthDs;

  @override
  Future<Either<Failure, GoogleDriveUploadResult>> uploadEncryptedBackup({
    required String absoluteFilePath,
    required Map<String, String> metadata,
  }) async {
    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      final ds = GoogleDriveBackupDs(client);
      final file = await ds.uploadBackup(
        File(absoluteFilePath),
        metadata: metadata,
      );
      final id = file.id;
      if (id == null || id.isEmpty) {
        return const Left(
          NetworkFailure(
            'Drive upload succeeded but returned no file id.',
            code: 'drive_upload_missing_id',
          ),
        );
      }
      final sizeBytes = _parseSize(file.size);
      return Right(
        GoogleDriveUploadResult(
          fileId: id,
          name: file.name,
          sizeBytes: sizeBytes,
        ),
      );
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, List<GoogleDriveRemoteBackupItem>>>
      listRemoteBackups() async {
    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      final ds = GoogleDriveBackupDs(client);
      final files = await ds.listBackups();
      return Right(files.map(_mapDriveFile).toList(growable: false));
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, GoogleDriveRemoteBackupItem>> fetchRemoteBackupById(
    String fileId,
  ) async {
    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      final ds = GoogleDriveBackupDs(client);
      final file = await ds.fetchBackupMetadata(fileId);
      return Right(_mapDriveFile(file));
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> downloadBackupToFile({
    required String fileId,
    required String destinationPath,
  }) async {
    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      final ds = GoogleDriveBackupDs(client);
      await ds.downloadBackup(fileId, destinationPath);
      return const Right(unit);
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, String>> downloadBackupToTemporaryFile(
    String fileId,
  ) async {
    final destinationPath = p.join(
      Directory.systemTemp.path,
      'daftar_drive_restore_${UuidUtil.generate()}.daftar',
    );
    final result = await downloadBackupToFile(
      fileId: fileId,
      destinationPath: destinationPath,
    );
    if (result case Left(:final value)) {
      await deleteIfPresent(destinationPath);
      return Left(value);
    }
    return Right(destinationPath);
  }

  @override
  Future<Either<Failure, Unit>> deleteRemoteBackup(String fileId) async {
    if (fileId.trim().isEmpty) {
      return const Left(
        ValidationFailure(
          'Google Drive file id cannot be empty.',
          code: 'drive_empty_file_id',
        ),
      );
    }
    try {
      final client = await _googleAuthDs.getAuthenticatedHttpClient();
      final ds = GoogleDriveBackupDs(client);
      await ds.deleteBackup(fileId);
      return const Right(unit);
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> pruneOldRemoteBackups({
    required int keepNewest,
  }) async {
    if (keepNewest < 1) {
      return const Left(
        ValidationFailure(
          'keepNewest must be at least 1.',
          code: 'drive_prune_invalid_keep',
        ),
      );
    }
    try {
      final listed = await listRemoteBackups();
      return listed.fold(
        Left.new,
        (items) async {
          if (items.length <= keepNewest) {
            return const Right(unit);
          }
          final toDelete = items.skip(keepNewest);
          for (final item in toDelete) {
            final id = item.id.trim();
            if (id.isEmpty) {
              continue;
            }
            try {
              await deleteRemoteBackup(id);
            } on Object {
              // Best-effort — never fail the parent upload on prune errors.
            }
          }
          return const Right(unit);
        },
      );
    } on Object catch (e) {
      return Left(_failureFromDriveOperation(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteIfPresent(String absolutePath) async {
    try {
      final file = File(absolutePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      return const Right(unit);
    } on Object catch (e) {
      return Left(
        StorageFailure(
          'Failed to delete temporary backup file: $e',
          code: 'drive_temp_delete_error',
        ),
      );
    }
  }

  GoogleDriveRemoteBackupItem _mapDriveFile(drive.File f) {
    final props = f.appProperties;
    Map<String, String>? mappedProps;
    if (props != null && props.isNotEmpty) {
      final out = <String, String>{};
      props.forEach((key, value) {
        if (value != null) {
          out[key] = value;
        }
      });
      mappedProps = out;
    }
    return GoogleDriveRemoteBackupItem(
      id: f.id ?? '',
      name: f.name ?? '',
      sizeBytes: _parseSize(f.size),
      modifiedTimeUtc: f.modifiedTime?.toUtc(),
      appProperties: mappedProps,
    );
  }

  int? _parseSize(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }
}

Failure _failureFromDriveOperation(Object e) {
  if (e is GoogleAuthNotSignedInException) {
    return AuthFailure(e.message, code: 'google_not_signed_in');
  }
  if (e is GoogleDriveGrantRevokedException) {
    return GoogleAuthFailureMapper.fromGrantRevokedException(e);
  }
  if (e is SocketException) {
    return NetworkFailure(
      'Network error: ${e.message}',
      code: 'drive_socket',
    );
  }
  if (e is TimeoutException) {
    return const NetworkFailure(
      'Google Drive request timed out.',
      code: 'drive_timeout',
    );
  }
  if (e is http.ClientException) {
    return NetworkFailure(
      'Network error: ${e.message}',
      code: 'drive_client',
    );
  }
  if (e is GoogleDriveBackupException) {
    return _failureFromGoogleDriveBackupException(e);
  }
  return NetworkFailure(
    'Google Drive operation failed: $e',
    code: 'drive_unexpected',
  );
}

Failure _failureFromGoogleDriveBackupException(GoogleDriveBackupException e) {
  if (_isDriveStorageQuotaExceeded(e)) {
    return const QuotaExceededFailure(
      'Your Google Drive is full. Free up space or delete old Daftar backups.',
      code: 'drive_storage_quota_exceeded',
    );
  }
  final status = e.status;
  if (status == 401) {
    return AuthFailure(
      e.message,
      code: 'drive_unauthorized',
    );
  }
  if (status == 403) {
    final reason = e.reason?.toLowerCase() ?? '';
    if (reason.contains('ratelimit') ||
        e.message.toLowerCase().contains('rate limit')) {
      return NetworkFailure(
        e.message,
        code: 'drive_transient_403',
      );
    }
    return AuthFailure(
      e.message,
      code: 'drive_forbidden',
    );
  }
  if (status != null && status >= 500 && status < 600) {
    return NetworkFailure(
      e.message,
      code: 'drive_http_$status',
    );
  }
  if (status == 408 || status == 429) {
    return NetworkFailure(
      e.message,
      code: 'drive_transient_$status',
    );
  }
  return NetworkFailure(
    e.message,
    code: 'drive_api_${status ?? 0}',
  );
}

bool _isDriveStorageQuotaExceeded(GoogleDriveBackupException e) {
  if (e.status != 403) {
    return false;
  }
  final r = e.reason?.toLowerCase();
  if (r == 'storagequotaexceeded') {
    return true;
  }
  final msg = e.message.toLowerCase();
  return msg.contains('storagequotaexceeded') || msg.contains('storage quota');
}
