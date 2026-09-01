import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/backup_metadata.dart' as domain;
import 'package:daftar/domain/enums/backup_type.dart';
import 'package:drift/drift.dart';

/// Bidirectional mapper between [db.BackupMetadata] Drift rows and
/// [domain.BackupMetadata] entities.
///
/// Extension methods allow call-site conversions without importing both
/// namespaces simultaneously in business-logic files.
extension BackupMetadataDriftMapper on db.BackupMetadata {
  /// Converts a Drift `backup_metadatas` row to the domain entity.
  domain.BackupMetadata toDomain() => domain.BackupMetadata(
    id: id,
    filePath: filePath,
    sizeBytes: sizeBytes,
    createdAt: createdAt,
    type: type,
    checksum: checksum,
    googleDriveFileId: googleDriveFileId,
  );
}

/// Converts a [domain.BackupMetadata] to a Drift insertion companion.
///
/// Used when persisting a newly created backup record to the DB.
extension BackupMetadataDomainMapper on domain.BackupMetadata {
  /// Returns a [db.BackupMetadatasCompanion] ready for `into().insert()`.
  db.BackupMetadatasCompanion toCompanion() =>
      db.BackupMetadatasCompanion.insert(
        id: id,
        filePath: filePath,
        sizeBytes: sizeBytes,
        createdAt: Value(createdAt),
        type: type,
        checksum: checksum,
        googleDriveFileId: Value(googleDriveFileId),
      );
}

/// Builds an insertion companion from raw fields.
///
/// Used by the backup repository when constructing a new metadata row
/// without a pre-existing domain entity.
db.BackupMetadatasCompanion buildBackupCompanion({
  required String id,
  required String filePath,
  required int sizeBytes,
  required DateTime createdAt,
  required BackupType type,
  required String checksum,
  String? googleDriveFileId,
}) =>
    db.BackupMetadatasCompanion.insert(
      id: id,
      filePath: filePath,
      sizeBytes: sizeBytes,
      createdAt: Value(createdAt),
      type: type,
      checksum: checksum,
      googleDriveFileId: Value(googleDriveFileId),
    );
