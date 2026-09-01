import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_local_ds.dart';
import 'package:daftar/data/datasources/local/backup_queue_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/repositories/google_identity_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed identity firewall for Google account switches.
class GoogleIdentityRepositoryImpl implements GoogleIdentityRepository {
  GoogleIdentityRepositoryImpl({
    required db.AppDatabase database,
    required BackupLocalDs backupLocalDs,
    required BackupQueueLocalDs backupQueueLocalDs,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  })  : _database = database,
        _backupLocalDs = backupLocalDs,
        _backupQueueLocalDs = backupQueueLocalDs,
        _auditLogLocalDataSource = auditLogLocalDataSource;

  final db.AppDatabase _database;
  final BackupLocalDs _backupLocalDs;
  final BackupQueueLocalDs _backupQueueLocalDs;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  @override
  Future<Either<Failure, Unit>> purgeDriveIdentityOnAccountSwitch({
    required String? oldEmail,
    required String newEmail,
    required String newAccountId,
  }) async {
    try {
      await _database.transaction(() async {
        await _backupLocalDs.staleGoogleDriveBackupFileIds();
        await _backupQueueLocalDs.clearAll();
        await _auditLogLocalDataSource.appendLog(
          AuditLogModel(
            id: UuidUtil.generate(),
            entityType: 'google_account',
            entityId: newAccountId,
            action: 'ACCOUNT_SWITCH',
            payload: _accountSwitchPayload(oldEmail, newEmail),
            timestamp: DateTime.now().toUtc(),
            deviceId: repositoryDeviceId,
          ),
        );
      });
      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  String _accountSwitchPayload(String? oldEmail, String newEmail) {
    final from =
        (oldEmail == null || oldEmail.isEmpty) ? '(unknown)' : oldEmail;
    return 'Changed from $from to $newEmail';
  }
}
