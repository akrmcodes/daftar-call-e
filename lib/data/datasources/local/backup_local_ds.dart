import 'dart:io';

import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local data source for backup file operations and metadata persistence.
///
/// Responsibilities:
/// - Locate the on-disk Drift database file.
/// - Checkpoint the SQLite WAL before reading the physical file.
/// - Read the raw database bytes for encryption.
/// - Persist `BackupMetadata` rows to the `backup_metadatas` table.
/// - Query existing backup history.
/// - Write encrypted backup files to the public Downloads directory via
///   a native Android MediaStore bridge, with internal-storage fallback.
///
/// All I/O here is raw file/DB access. Encryption and business-rule
/// enforcement live in the repository and use-case layers respectively.
class BackupLocalDs {
  /// Creates a [BackupLocalDs] tied to the given `AppDatabase` instance.
  BackupLocalDs(
    db.AppDatabase? database, {
    Future<Directory> Function()? documentsDirectoryResolver,
    bool Function()? publicExportEnabledResolver,
  }) : _db = database,
       _documentsDirectoryResolver =
           documentsDirectoryResolver ?? getApplicationDocumentsDirectory,
       _publicExportEnabledResolver =
           publicExportEnabledResolver ?? (() => true);

  /// File-only accessor for recovery when Drift cannot boot.
  factory BackupLocalDs.fileOnly({
    Future<Directory> Function()? documentsDirectoryResolver,
    bool Function()? publicExportEnabledResolver,
  }) {
    return BackupLocalDs(
      null,
      documentsDirectoryResolver: documentsDirectoryResolver,
      publicExportEnabledResolver: publicExportEnabledResolver,
    );
  }

  final db.AppDatabase? _db;
  final Future<Directory> Function() _documentsDirectoryResolver;
  final bool Function() _publicExportEnabledResolver;

  db.AppDatabase get _requireDb {
    final database = _db;
    if (database == null) {
      throw StateError('An open database is required for this operation.');
    }
    return database;
  }

  static const MethodChannel _publicDownloadsChannel = MethodChannel(
    'daftar/public_downloads',
  );

  // ── Database file location ───────────────────────────────────────────

  /// Returns the absolute path to the on-disk Drift database file.
  ///
  /// Uses the same filename as `bootstrap.dart` to ensure we locate
  /// the correct physical file on disk.
  Future<String> getDatabasePath() async {
    final dir = await _documentsDirectoryResolver();
    return p.join(dir.path, 'daftar.sqlite');
  }

  // ── WAL Checkpoint ───────────────────────────────────────────────────

  /// Forces a WAL checkpoint to ensure all pending writes are flushed
  /// to the main database file before we copy it.
  ///
  /// Uses `PRAGMA wal_checkpoint(TRUNCATE)` which:
  /// 1. Copies all WAL frames to the main DB file.
  /// 2. Resets the WAL file to zero length.
  ///
  /// This guarantees the physical `.sqlite` file on disk is a complete,
  /// consistent snapshot at the moment of the backup.
  ///
  /// CRITICAL: Must be called immediately before [readDatabaseBytes] to
  /// prevent partial or stale data being captured in the backup.
  Future<void> checkpointWal() async {
    final database = _db;
    if (database == null) {
      throw StateError('WAL checkpoint requires an open database.');
    }
    await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  // ── Database file reading ────────────────────────────────────────────

  /// Reads the raw bytes of the SQLite database file from disk.
  ///
  /// Must be called after [checkpointWal] to ensure consistency.
  ///
  /// Throws [FileSystemException] if the file cannot be read.
  Future<Uint8List> readDatabaseBytes() async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      throw FileSystemException('Database file not found', dbPath);
    }
    return dbFile.readAsBytes();
  }

  // ── Backup file I/O ──────────────────────────────────────────────────

  /// Writes [encryptedBytes] to a new `.daftar` backup file.
  ///
  /// **Strategy:**
  /// 1. Write to app-private internal storage first (always succeeds).
  /// 2. Copy the file into the **real public Downloads/Daftar** folder
  ///    on Android using a native MediaStore bridge.
  /// 3. On iOS, write to `Documents/Daftar` (visible in Files app via
  ///    `UIFileSharingEnabled`).
  ///
  /// Returns the absolute path of the **internal** file (used for
  /// metadata tracking and share/restore). The public copy in Downloads
  /// is a best-effort convenience for the user.
  ///
  /// Throws [FileSystemException] on write failure.
  Future<String> writeBackupFile(
    Uint8List encryptedBytes,
    DateTime timestamp,
  ) async {
    final fileName = _buildFileName(timestamp);

    // Step 1: Always persist to internal app storage first.
    final internalDir = await _ensureInternalBackupDirectory();
    final internalFile = File(p.join(internalDir.path, fileName));
    await internalFile.writeAsBytes(encryptedBytes, flush: true);

    // Step 2: Copy to public Downloads (best-effort, never blocks backup).
    if (Platform.isAndroid) {
      await _copyToPublicDownloads(internalFile.path, fileName);
    } else if (Platform.isIOS) {
      await _copyToIosSharedDirectory(internalFile, fileName);
    }

    return internalFile.path;
  }

  /// Reads the raw bytes of an existing `.daftar` backup file.
  ///
  /// Throws [FileSystemException] if the file does not exist or is unreadable.
  Future<Uint8List> readBackupFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Backup file not found', filePath);
    }
    return file.readAsBytes();
  }

  // ── BackupMetadata persistence ───────────────────────────────────────

  /// Inserts a new backup metadata row into the `backup_metadatas` table.
  ///
  /// Returns the newly persisted Drift row.
  ///
  /// Throws [DriftWrappedException] on DB constraint violations.
  Future<db.BackupMetadata> insertMetadata(
    db.BackupMetadatasCompanion companion,
  ) async {
    final database = _requireDb;
    await database
        .into(database.backupMetadatas)
        .insert(companion, mode: InsertMode.insertOrFail);

    // Read back using the UUID from the companion — Drift's insert()
    // returns the SQLite rowid (int) which does not match a text UUID PK.
    final uuid = companion.id.value;
    return (database.select(
      database.backupMetadatas,
    )..where((t) => t.id.equals(uuid))).getSingle();
  }

  /// Bulk-inserts backup metadata rows using `insertOrReplace` to
  /// survive conflicts with rows that already exist in the restored DB.
  ///
  /// Used by the metadata re-insert step after a database restore.
  Future<void> bulkInsertMetadata(
    List<db.BackupMetadatasCompanion> companions,
  ) async {
    final database = _requireDb;
    await database.batch((batch) {
      for (final companion in companions) {
        batch.insert(
          database.backupMetadatas,
          companion,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Returns all backup metadata rows ordered by `createdAt` descending.
  ///
  /// Optionally filters by `BackupType` when [filterType] is non-null.
  Future<List<db.BackupMetadata>> getAllMetadata({BackupType? filterType}) {
    final database = _requireDb;
    final query = database.select(database.backupMetadatas)
      ..orderBy(
        [(t) => OrderingTerm.desc(t.createdAt)],
      );
    if (filterType != null) {
      query.where((t) => t.type.equalsValue(filterType));
    }
    return query.get();
  }

  /// Returns a single backup metadata row by [id], or null if not found.
  Future<db.BackupMetadata?> getMetadataById(String id) {
    final database = _requireDb;
    return (database.select(
      database.backupMetadatas,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Deletes the backup metadata row with the given [id].
  ///
  /// Returns the number of rows deleted (0 or 1).
  Future<int> deleteMetadata(String id) {
    final database = _requireDb;
    return (database.delete(
      database.backupMetadatas,
    )..where((t) => t.id.equals(id))).go();
  }

  // ── Google Drive identity purge ─────────────────────────────────────

  /// Alias for [staleGoogleDriveBackupFileIds].
  Future<void> clearAllGoogleDriveFileIds() => staleGoogleDriveBackupFileIds();

  /// Nullifies `googleDriveFileId` on Google Drive backup rows so the UI retains
  /// history but cannot download from the prior account.
  Future<void> staleGoogleDriveBackupFileIds() async {
    final database = _db;
    if (database == null) {
      return;
    }
    await (database.update(database.backupMetadatas)
          ..where((t) => t.type.equalsValue(BackupType.googleDrive)))
        .write(
      const db.BackupMetadatasCompanion(googleDriveFileId: Value(null)),
    );
  }

  // ── Restore helpers ─────────────────────────────────────────────────

  /// Cleanly closes the active Drift database connection.
  ///
  /// **CRITICAL:** This MUST be called before replacing the database file
  /// on disk. Failure to close the connection before overwriting the file
  /// will result in `SQLITE_CORRUPT` errors.
  ///
  /// After calling this method, no further database operations are
  /// possible until the app is restarted with a fresh connection.
  Future<void> closeDatabase() async {
    final database = _db;
    if (database == null) {
      return;
    }
    try {
      await database.close();
    } on Object {
      // Corrupt or already closed — restore can still replace files on disk.
    }
  }

  /// Deletes SQLite WAL (Write-Ahead Log) and SHM (Shared Memory) files
  /// associated with the active database.
  ///
  /// **CRITICAL SQLite RULE:** When replacing a database file, stale
  /// `-wal` and `-shm` files from the previous database MUST be removed.
  /// If old WAL files remain on disk, SQLite will attempt to replay them
  /// against the restored database, causing immediate corruption.
  ///
  /// This method is idempotent — it silently succeeds if the files do
  /// not exist (e.g., when WAL mode was not active).
  Future<void> deleteWalAndShmFiles() async {
    final dbPath = await getDatabasePath();
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');

    if (walFile.existsSync()) {
      await walFile.delete();
    }
    if (shmFile.existsSync()) {
      await shmFile.delete();
    }
  }

  /// Writes decrypted database bytes to a temporary file for staging.
  ///
  /// The temp file (`daftar_restored.sqlite.tmp`) sits next to the main
  /// database file. It is used as the staging area before the atomic
  /// rename that completes the restore.
  ///
  /// Returns the [File] handle to the written temp file.
  ///
  /// Throws [FileSystemException] on write failure.
  Future<File> writeTempRestoreFile(Uint8List decryptedBytes) async {
    final dbPath = await getDatabasePath();
    final tempFile = File('$dbPath.tmp');
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    return tempFile;
  }

  /// Performs the atomic file swap: deletes the old database and renames
  /// the temp restore file to take its place.
  ///
  /// Preconditions (caller must ensure):
  /// 1. [closeDatabase] has been called.
  /// 2. [deleteWalAndShmFiles] has been called.
  ///
  /// Throws [FileSystemException] if the rename or delete fails.
  Future<void> renameTempToDatabase(File tempFile) async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);

    // Delete the old database file if it exists.
    if (dbFile.existsSync()) {
      await dbFile.delete();
    }

    // Rename the temp file to become the new database.
    await tempFile.rename(dbPath);
  }

  // ── Private helpers ──────────────────────────────────────────────────

  Future<Directory> _ensureInternalBackupDirectory() async {
    final dir = await _documentsDirectoryResolver();
    final backupDir = Directory(p.join(dir.path, 'backups'));
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Copies the backup file into the public Downloads/Daftar folder on
  /// Android using the native MediaStore bridge.
  ///
  /// This is best-effort — if the copy fails, the internal file still
  /// exists and is fully functional for restore/share operations.
  Future<void> _copyToPublicDownloads(
    String sourceFilePath,
    String fileName,
  ) async {
    if (!_publicExportEnabledResolver()) {
      return;
    }

    try {
      await _publicDownloadsChannel.invokeMethod<bool>(
        'copyBackupToDownloadsDaftar',
        {
          'sourceFilePath': sourceFilePath,
          'fileName': fileName,
        },
      );
    } on Object {
      // Best-effort: internal file remains the source of truth.
    }
  }

  /// Copies the backup file into `Documents/Daftar` on iOS for
  /// visibility in the Files app.
  Future<void> _copyToIosSharedDirectory(
    File sourceFile,
    String fileName,
  ) async {
    try {
      final docs = await _documentsDirectoryResolver();
      final sharedDir = Directory(p.join(docs.path, 'Daftar'));
      if (!sharedDir.existsSync()) {
        await sharedDir.create(recursive: true);
      }
      await sourceFile.copy(p.join(sharedDir.path, fileName));
    } on Object {
      // Best-effort: internal file remains the source of truth.
    }
  }

  /// Builds the backup file name from the given [timestamp].
  ///
  /// Format: `Daftar_Backup_YYYYMMDD_HHMMSS.daftar`
  String _buildFileName(DateTime timestamp) {
    final dt = timestamp.toUtc();
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return 'Daftar_Backup_$year$month${day}_$hour$minute$second.daftar';
  }
}
