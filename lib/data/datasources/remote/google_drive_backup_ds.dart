import 'dart:io' as io;

import 'package:daftar/data/datasources/remote/google_drive_backup_exceptions.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Remote data source for encrypted `.daftar` backups in Drive `appDataFolder`.
///
/// Callers obtain an authenticated `http.Client` (for example from
/// `GoogleAuthDs.getAuthenticatedHttpClient`) and construct this class per
/// operation so tokens stay fresh.
class GoogleDriveBackupDs {
  /// Creates a data source that performs Drive v3 calls via [authClient].
  GoogleDriveBackupDs(http.Client authClient) : _authClient = authClient;

  final http.Client _authClient;

  static const int _resumableUploadThresholdBytes = 5 * 1024 * 1024;

  static const String _listFields =
      'nextPageToken, files(id, name, size, modifiedTime, appProperties)';

  static const String _createResponseFields =
      'id, name, size, modifiedTime, appProperties';

  /// Uploads [encryptedFile] into the hidden app data folder with [metadata]
  /// stored as Drive `appProperties`.
  ///
  /// Uses a resumable upload session for files larger than 5 MB so chunked
  /// uploads and retries are handled by the discovery client; smaller files
  /// use the default upload path.
  Future<drive.File> uploadBackup(
    io.File encryptedFile, {
    required Map<String, String> metadata,
  }) async {
    final driveApi = drive.DriveApi(_authClient);
    final length = encryptedFile.lengthSync();
    final uploadOptions = length > _resumableUploadThresholdBytes
        ? drive.ResumableUploadOptions()
        : drive.UploadOptions.defaultOptions;

    final baseName = p.basename(encryptedFile.path);
    final driveName = baseName.endsWith('.daftar')
        ? baseName
        : '${p.basenameWithoutExtension(baseName)}.daftar';

    final driveFile = drive.File()
      ..name = driveName
      ..parents = const ['appDataFolder']
      ..appProperties = metadata;

    final media = drive.Media(encryptedFile.openRead(), length);

    try {
      return await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        uploadOptions: uploadOptions,
        $fields: _createResponseFields,
      );
    } on drive.DetailedApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toDetailedException(e), st);
    } on drive.ApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toApiException(e), st);
    }
  }

  /// Lists `.daftar` files in `appDataFolder`, newest first.
  ///
  /// Requests `appProperties` explicitly via partial response fields.
  Future<List<drive.File>> listBackups() async {
    final driveApi = drive.DriveApi(_authClient);
    final all = <drive.File>[];
    String? pageToken;

    try {
      do {
        final response = await driveApi.files.list(
          corpora: 'user',
          spaces: 'appDataFolder',
          q: "'appDataFolder' in parents and trashed = false",
          orderBy: 'modifiedTime desc',
          pageSize: 100,
          pageToken: pageToken,
          $fields: _listFields,
        );
        all.addAll(response.files ?? const <drive.File>[]);
        pageToken = response.nextPageToken;
      } while (pageToken != null);
      return all
          .where((file) => (file.name ?? '').toLowerCase().endsWith('.daftar'))
          .toList(growable: false);
    } on drive.DetailedApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toDetailedException(e), st);
    } on drive.ApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toApiException(e), st);
    }
  }

  /// Downloads file [fileId] to [savePath] by streaming bytes to disk.
  Future<io.File> downloadBackup(String fileId, String savePath) async {
    final driveApi = drive.DriveApi(_authClient);
    final outFile = io.File(savePath);
    await outFile.parent.create(recursive: true);

    try {
      final result = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (result is! drive.Media) {
        throw GoogleDriveBackupException(
          'Expected media body from Drive files.get',
          cause: result,
        );
      }
      final media = result;
      final sink = outFile.openWrite();
      try {
        await media.stream.pipe(sink);
      } on Object catch (e, st) {
        if (outFile.existsSync()) {
          try {
            outFile.deleteSync();
          } on Object {
            // Best-effort cleanup of a partial file.
          }
        }
        Error.throwWithStackTrace(e, st);
      }
      return outFile;
    } on drive.DetailedApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toDetailedException(e), st);
    } on drive.ApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toApiException(e), st);
    }
  }

  /// Loads Drive metadata for [fileId], including `appProperties`.
  Future<drive.File> fetchBackupMetadata(String fileId) async {
    final driveApi = drive.DriveApi(_authClient);
    try {
      final result = await driveApi.files.get(
        fileId,
        $fields: 'id, name, size, modifiedTime, appProperties',
      );
      if (result is! drive.File) {
        throw GoogleDriveBackupException(
          'Expected file metadata from Drive files.get',
          cause: result,
        );
      }
      return result;
    } on drive.DetailedApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toDetailedException(e), st);
    } on drive.ApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toApiException(e), st);
    }
  }

  /// Permanently deletes the Drive file identified by [fileId].
  Future<void> deleteBackup(String fileId) async {
    final driveApi = drive.DriveApi(_authClient);
    try {
      await driveApi.files.delete(fileId);
    } on drive.DetailedApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toDetailedException(e), st);
    } on drive.ApiRequestError catch (e, st) {
      Error.throwWithStackTrace(_toApiException(e), st);
    }
  }

  GoogleDriveBackupException _toDetailedException(
    drive.DetailedApiRequestError e,
  ) {
    final detail = e.errors.isNotEmpty ? e.errors.first.message : null;
    final text = detail ?? e.message ?? 'Google Drive API error';
    final reason = e.errors.isNotEmpty ? e.errors.first.reason : null;
    return GoogleDriveBackupException(
      text,
      status: e.status,
      reason: reason,
      cause: e,
    );
  }

  GoogleDriveBackupException _toApiException(drive.ApiRequestError e) {
    return GoogleDriveBackupException(
      e.message ?? 'Google Drive API error',
      cause: e,
    );
  }
}
