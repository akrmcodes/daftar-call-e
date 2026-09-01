import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/data/datasources/local/agent_turn_local_ds.dart';
import 'package:daftar/data/datasources/local/audit_log_local_ds.dart';
import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_turn_model.dart';
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/data/repositories/repository_utils.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Drift-backed implementation of [AgentTurnRepository].
class AgentTurnRepositoryImpl implements AgentTurnRepository {
  /// Creates an agent-turn repository implementation.
  AgentTurnRepositoryImpl({
    required AgentTurnLocalDataSource agentTurnLocalDataSource,
    required AuditLogLocalDataSource auditLogLocalDataSource,
  }) : _agentTurnLocalDataSource = agentTurnLocalDataSource,
       _auditLogLocalDataSource = auditLogLocalDataSource;

  final AgentTurnLocalDataSource _agentTurnLocalDataSource;
  final AuditLogLocalDataSource _auditLogLocalDataSource;

  db.AppDatabase get _database => _agentTurnLocalDataSource.database;

  @override
  Future<Either<Failure, AgentTurn>> append(AgentTurn turn) async {
    try {
      final model = AgentTurnModel.fromDomain(turn);
      await _database.transaction(() async {
        await _agentTurnLocalDataSource.insertTurn(model);
        await _appendAuditLog(
          entityId: model.id,
          action: 'CREATE',
          payload: encodePayload({
            'sessionId': model.sessionId,
            'role': model.role.name,
            'confirmState': model.confirmState.name,
            'proposalId': model.proposalId,
            'toolName': model.toolName,
          }),
        );
      });
      return Right(model.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentTurn>> updateConfirmState({
    required String turnId,
    required AgentTurnConfirmState confirmState,
  }) async {
    try {
      final existing = await _agentTurnLocalDataSource.getById(turnId);
      if (existing == null) {
        return Left(notFoundFailure('AgentTurn', turnId));
      }

      final now = DateTime.now().toUtc();
      final updated = AgentTurnModel(
        id: existing.id,
        sessionId: existing.sessionId,
        role: existing.role,
        confirmState: confirmState,
        createdAt: existing.createdAt,
        updatedAt: now,
        transcript: existing.transcript,
        proposalJson: existing.proposalJson,
        proposalId: existing.proposalId,
        toolName: existing.toolName,
        isDeleted: existing.isDeleted,
        syncVersion: existing.syncVersion + 1,
      );

      await _database.transaction(() async {
        await _agentTurnLocalDataSource.updateTurn(updated);
        await _appendAuditLog(
          entityId: updated.id,
          action: 'UPDATE',
          payload: encodePayload({
            'confirmState': updated.confirmState.name,
          }),
        );
      });

      return Right(updated.toDomain());
    } on Object catch (error) {
      return Left(databaseFailure(error));
    }
  }

  @override
  Future<Either<Failure, AgentTurn?>> findByProposalId(
    String proposalId,
  ) async {
    try {
      final existing = await _agentTurnLocalDataSource.getByProposalId(
        proposalId,
      );
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
        entityType: 'agent_turn',
        entityId: entityId,
        action: action,
        payload: payload,
        timestamp: DateTime.now().toUtc(),
        deviceId: repositoryDeviceId,
      ),
    );
  }
}
