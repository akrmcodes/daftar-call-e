import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/agent_turn.dart' as domain;
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of an agent turn.
class AgentTurnModel {
  /// Creates an agent-turn data model.
  const AgentTurnModel({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.confirmState,
    required this.createdAt,
    required this.updatedAt,
    this.transcript,
    this.proposalJson,
    this.proposalId,
    this.toolName,
    this.isDeleted = false,
    this.syncVersion = 0,
  });

  /// Builds a data model from a domain entity.
  factory AgentTurnModel.fromDomain(domain.AgentTurn turn) {
    return AgentTurnModel(
      id: turn.id,
      sessionId: turn.sessionId,
      role: turn.role,
      confirmState: turn.confirmState,
      createdAt: turn.createdAt,
      updatedAt: turn.updatedAt,
      transcript: turn.transcript,
      proposalJson: turn.proposalJson,
      proposalId: turn.proposalId,
      toolName: turn.toolName,
      isDeleted: turn.isDeleted,
      syncVersion: turn.syncVersion,
    );
  }

  /// Builds a data model from a Drift row.
  factory AgentTurnModel.fromDrift(db.AgentTurn turn) {
    return AgentTurnModel(
      id: turn.id,
      sessionId: turn.sessionId,
      role: turn.role,
      confirmState: turn.confirmState,
      createdAt: turn.createdAt,
      updatedAt: turn.updatedAt,
      transcript: turn.transcript,
      proposalJson: turn.proposalJson,
      proposalId: turn.proposalId,
      toolName: turn.toolName,
      isDeleted: turn.isDeleted,
      syncVersion: turn.syncVersion,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory AgentTurnModel.fromCompanion(db.AgentTurnsCompanion companion) {
    return AgentTurnModel(
      id: _requiredValue(companion.id, 'id'),
      sessionId: _requiredValue(companion.sessionId, 'sessionId'),
      role: _requiredValue(companion.role, 'role'),
      confirmState: _requiredValue(companion.confirmState, 'confirmState'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      transcript: _optionalNullableValue(companion.transcript),
      proposalJson: _optionalNullableValue(companion.proposalJson),
      proposalId: _optionalNullableValue(companion.proposalId),
      toolName: _optionalNullableValue(companion.toolName),
      isDeleted: _optionalValue(companion.isDeleted, false),
      syncVersion: _optionalValue(companion.syncVersion, 0),
    );
  }

  /// Unique identifier.
  final String id;

  /// Parent session UUID.
  final String sessionId;

  /// Who produced this turn.
  final AgentTurnRole role;

  /// Confirm-gate state.
  final AgentTurnConfirmState confirmState;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Optional transcript text.
  final String? transcript;

  /// Optional proposal JSON.
  final String? proposalJson;

  /// Optional proposal id.
  final String? proposalId;

  /// Optional tool name.
  final String? toolName;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Sync conflict resolution version.
  final int syncVersion;

  /// Converts this model back to the domain entity.
  domain.AgentTurn toDomain() {
    return domain.AgentTurn(
      id: id,
      sessionId: sessionId,
      role: role,
      confirmState: confirmState,
      createdAt: createdAt,
      updatedAt: updatedAt,
      transcript: transcript,
      proposalJson: proposalJson,
      proposalId: proposalId,
      toolName: toolName,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.AgentTurn toDrift() {
    return db.AgentTurn(
      id: id,
      sessionId: sessionId,
      role: role,
      confirmState: confirmState,
      createdAt: createdAt,
      updatedAt: updatedAt,
      transcript: transcript,
      proposalJson: proposalJson,
      proposalId: proposalId,
      toolName: toolName,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.AgentTurnsCompanion toCompanion() {
    return toDrift().toCompanion(false);
  }
}

T _requiredValue<T>(drift.Value<T> value, String fieldName) {
  if (!value.present) {
    throw StateError(
      'Missing required field "$fieldName" in Drift companion.',
    );
  }
  return value.value;
}

T _optionalValue<T>(drift.Value<T> value, T fallback) {
  return value.present ? value.value : fallback;
}

T? _optionalNullableValue<T>(drift.Value<T?> value) {
  return value.present ? value.value : null;
}
