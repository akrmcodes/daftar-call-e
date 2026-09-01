import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/agent_outbox_item.dart' as domain;
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of an agent outbox row.
class AgentOutboxItemModel {
  /// Creates an agent-outbox data model.
  const AgentOutboxItemModel({
    required this.id,
    required this.kind,
    required this.status,
    required this.payloadJson,
    required this.createdAt,
    required this.updatedAt,
    this.attempts = 0,
    this.nextRetryAt,
  });

  /// Builds a data model from a domain entity.
  factory AgentOutboxItemModel.fromDomain(domain.AgentOutboxItem item) {
    return AgentOutboxItemModel(
      id: item.id,
      kind: item.kind,
      status: item.status,
      payloadJson: item.payloadJson,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      attempts: item.attempts,
      nextRetryAt: item.nextRetryAt,
    );
  }

  /// Builds a data model from a Drift row.
  factory AgentOutboxItemModel.fromDrift(db.AgentOutboxRow row) {
    return AgentOutboxItemModel(
      id: row.id,
      kind: row.kind,
      status: row.status,
      payloadJson: row.payloadJson,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      attempts: row.attempts,
      nextRetryAt: row.nextRetryAt,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory AgentOutboxItemModel.fromCompanion(
    db.AgentOutboxRowsCompanion companion,
  ) {
    return AgentOutboxItemModel(
      id: _requiredValue(companion.id, 'id'),
      kind: _requiredValue(companion.kind, 'kind'),
      status: _requiredValue(companion.status, 'status'),
      payloadJson: _requiredValue(companion.payloadJson, 'payloadJson'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      attempts: _optionalValue(companion.attempts, 0),
      nextRetryAt: _optionalNullableValue(companion.nextRetryAt),
    );
  }

  /// Unique identifier.
  final String id;

  /// Queue kind (e.g. `pending_run`).
  final String kind;

  /// Queue status.
  final AgentOutboxStatus status;

  /// JSON payload.
  final String payloadJson;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Processing attempt count.
  final int attempts;

  /// Earliest retry time.
  final DateTime? nextRetryAt;

  /// Converts this model back to the domain entity.
  domain.AgentOutboxItem toDomain() {
    return domain.AgentOutboxItem(
      id: id,
      kind: kind,
      status: status,
      payloadJson: payloadJson,
      createdAt: createdAt,
      updatedAt: updatedAt,
      attempts: attempts,
      nextRetryAt: nextRetryAt,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.AgentOutboxRow toDrift() {
    return db.AgentOutboxRow(
      id: id,
      kind: kind,
      status: status,
      payloadJson: payloadJson,
      createdAt: createdAt,
      updatedAt: updatedAt,
      attempts: attempts,
      nextRetryAt: nextRetryAt,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.AgentOutboxRowsCompanion toCompanion() {
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
