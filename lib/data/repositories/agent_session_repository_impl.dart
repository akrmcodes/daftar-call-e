import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/agent_session_local_ds.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_session_model.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [AgentSessionRepository].
class AgentSessionRepositoryImpl implements AgentSessionRepository {
  /// Creates an agent-session repository implementation.
  AgentSessionRepositoryImpl({
    required AgentSessionLocalDataSource agentSessionLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _agentSessionLocalDataSource = agentSessionLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource;

  final AgentSessionLocalDataSource _agentSessionLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  db.AppDatabase get _database => _agentSessionLocalDataSource.database;

  @override
  Future<Either<Failure, AgentSession>> create(AgentSession session) async {
    try {
      final model = AgentSessionModel.fromDomain(session);
      await _database.transaction(() async {
        await _agentSessionLocalDataSource.insertSession(model);
        await _appendAuditLog(
          entityId: model.id,
          action: 'CREATE',
          payload: encodePayload({
            'mode': model.mode.name,
            'status': model.status.name,
            'correlationId': model.correlationId,
          }),
        );
      });
      return Right(model.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentSession>> complete({
    required String sessionId,
    required AgentSessionStatus status,
  }) async {
    try {
      final existing = await _agentSessionLocalDataSource.getById(sessionId);
      if (existing == null) {
        return Left(notFoundFailure('AgentSession', sessionId));
      }

      final now = DateTime.now().toUtc();
      final updated = AgentSessionModel(
        id: existing.id,
        mode: existing.mode,
        status: status,
        startedAt: existing.startedAt,
        createdAt: existing.createdAt,
        updatedAt: now,
        endedAt: now,
        correlationId: existing.correlationId,
        isDeleted: existing.isDeleted,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _agentSessionLocalDataSource.updateSession(updated);
        await _appendAuditLog(
          entityId: updated.id,
          action: 'UPDATE',
          payload: encodePayload({
            'status': updated.status.name,
            'endedAt': updated.endedAt?.toIso8601String(),
          }),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentSession>> getById(String id) async {
    try {
      final existing = await _agentSessionLocalDataSource.getById(id);
      if (existing == null) {
        return Left(notFoundFailure('AgentSession', id));
      }
      return Right(existing.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentSession?>> findActive({
    required AgentSessionMode mode,
  }) async {
    try {
      final existing = await _agentSessionLocalDataSource.findActive(mode);
      return Right(existing?.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  Future<void> _appendAuditLog({
    required String entityId,
    required String action,
    String? payload,
  }) async {
    await _auditLogLocalDataSource.appendLog(
      AuditLogModel(
        id: UuidUtil.generate(),
        entityType: 'agent_session',
        entityId: entityId,
        action: action,
        payload: payload,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }
}
