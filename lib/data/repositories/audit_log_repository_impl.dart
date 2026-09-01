import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/audit_log.dart';
import 'package:daftar/domain/repositories/audit_log_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [AuditLogRepository].
class AuditLogRepositoryImpl implements AuditLogRepository {
  /// Creates an audit log repository implementation.
  AuditLogRepositoryImpl({
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _auditLogLocalDataSource = auditLogLocalDataSource;

  final AuditLogLocalDataSource _auditLogLocalDataSource;

  @override
  Future<Either<Failure, Unit>> append(AppendAuditLogParams params) async {
    try {
      await _auditLogLocalDataSource.appendLog(
        AuditLogModel(
          id: UuidUtil.generate(),
          entityType: params.entityType,
          entityId: params.entityId,
          action: params.action,
          payload: params.payload,
          timestamp: DateTime.now().toUtc(),
          deviceId: repositoryDeviceId,
        ),
      );

      return const Right(unit);
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<AuditLog>>> getByEntity(
    String entityType,
    String entityId,
  ) async {
    try {
      final logs = await _auditLogLocalDataSource.getLogsByEntity(
        entityType,
        entityId,
      );
      return Right(logs.map((log) => log.toDomain()).toList(growable: false));
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, List<AuditLog>>> getRecent({int limit = 50}) async {
    try {
      final logs = await _auditLogLocalDataSource.getRecentLogs(limit);
      return Right(logs.map((log) => log.toDomain()).toList(growable: false));
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }
}
