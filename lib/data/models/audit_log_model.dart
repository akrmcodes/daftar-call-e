import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/audit_log.dart' as domain;

/// Data-layer representation of an audit log entry.
class AuditLogModel {
  /// Creates an audit log model.
  const AuditLogModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.timestamp,
    required this.deviceId,
    this.payload,
  });

  /// Creates a model from the domain entity.
  factory AuditLogModel.fromDomain(domain.AuditLog log) {
    return AuditLogModel(
      id: log.id,
      entityType: log.entityType,
      entityId: log.entityId,
      action: log.action,
      payload: log.payload,
      timestamp: log.timestamp,
      deviceId: log.deviceId,
    );
  }

  /// Primary key.
  final String id;

  /// Entity type.
  final String entityType;

  /// Entity ID.
  final String entityId;

  /// Action performed.
  final String action;

  /// Optional payload JSON.
  final String? payload;

  /// Event timestamp.
  final DateTime timestamp;

  /// Device identifier.
  final String deviceId;

  /// Converts this model back to the domain entity.
  domain.AuditLog toDomain() {
    return domain.AuditLog(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      timestamp: timestamp,
      deviceId: deviceId,
      payload: payload,
    );
  }

  /// Converts this model to the generated Drift row.
  db.AuditLog toDrift() {
    return db.AuditLog(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }

  /// Converts this model to a Drift companion.
  db.AuditLogsCompanion toCompanion() => toDrift().toCompanion(false);
}
