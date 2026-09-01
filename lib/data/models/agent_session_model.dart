import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/agent_session.dart' as domain;
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of an agent session.
class AgentSessionModel {
  /// Creates an agent-session data model.
  const AgentSessionModel({
    required this.id,
    required this.mode,
    required this.status,
    required this.startedAt,
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
    this.correlationId,
    this.isDeleted = false,
    this.syncVersion = 0,
  });

  /// Builds a data model from a domain entity.
  factory AgentSessionModel.fromDomain(domain.AgentSession session) {
    return AgentSessionModel(
      id: session.id,
      mode: session.mode,
      status: session.status,
      startedAt: session.startedAt,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      endedAt: session.endedAt,
      correlationId: session.correlationId,
      isDeleted: session.isDeleted,
      syncVersion: session.syncVersion,
    );
  }

  /// Builds a data model from a Drift row.
  factory AgentSessionModel.fromDrift(db.AgentSession session) {
    return AgentSessionModel(
      id: session.id,
      mode: session.mode,
      status: session.status,
      startedAt: session.startedAt,
      createdAt: session.createdAt,
      updatedAt: session.updatedAt,
      endedAt: session.endedAt,
      correlationId: session.correlationId,
      isDeleted: session.isDeleted,
      syncVersion: session.syncVersion,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory AgentSessionModel.fromCompanion(
    db.AgentSessionsCompanion companion,
  ) {
    return AgentSessionModel(
      id: _requiredValue(companion.id, 'id'),
      mode: _requiredValue(companion.mode, 'mode'),
      status: _requiredValue(companion.status, 'status'),
      startedAt: _requiredValue(companion.startedAt, 'startedAt'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      endedAt: _optionalNullableValue(companion.endedAt),
      correlationId: _optionalNullableValue(companion.correlationId),
      isDeleted: _optionalValue(companion.isDeleted, false),
      syncVersion: _optionalValue(companion.syncVersion, 0),
    );
  }

  /// Unique identifier.
  final String id;

  /// Capture vs closing.
  final AgentSessionMode mode;

  /// Lifecycle status.
  final AgentSessionStatus status;

  /// UTC session start.
  final DateTime startedAt;

  /// UTC session end.
  final DateTime? endedAt;

  /// Optional correlation id.
  final String? correlationId;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Sync conflict resolution version.
  final int syncVersion;

  /// Converts this model back to the domain entity.
  domain.AgentSession toDomain() {
    return domain.AgentSession(
      id: id,
      mode: mode,
      status: status,
      startedAt: startedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      endedAt: endedAt,
      correlationId: correlationId,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.AgentSession toDrift() {
    return db.AgentSession(
      id: id,
      mode: mode,
      status: status,
      startedAt: startedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      endedAt: endedAt,
      correlationId: correlationId,
      isDeleted: isDeleted,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.AgentSessionsCompanion toCompanion() {
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
