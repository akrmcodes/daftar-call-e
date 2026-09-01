import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/audit_log_model.dart';
import 'package:daftar/domain/entities/audit_log.dart' as domain;

/// Seamless conversions for audit log domain, data, and Drift types.
extension AuditLogDomainMapper on domain.AuditLog {
  /// Converts a domain audit log to the data-layer model.
  AuditLogModel toModel() => AuditLogModel.fromDomain(this);

  /// Converts a domain audit log directly to a Drift row.
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

  /// Converts a domain audit log to a Drift companion.
  db.AuditLogsCompanion toCompanion() => toDrift().toCompanion(false);
}

/// Seamless conversions for generated Drift audit log rows.
extension AuditLogDriftMapper on db.AuditLog {
  /// Converts a Drift audit log row to the data-layer model.
  AuditLogModel toModel() {
    return AuditLogModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      timestamp: timestamp,
      deviceId: deviceId,
    );
  }

  /// Converts a Drift audit log row back to the domain entity.
  domain.AuditLog toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift audit log companions.
extension AuditLogCompanionMapper on db.AuditLogsCompanion {
  /// Converts a Drift audit log companion to the data-layer model.
  AuditLogModel toModel() {
    return AuditLogModel(
      id: id.value,
      entityType: entityType.value,
      entityId: entityId.value,
      action: action.value,
      payload: payload.present ? payload.value : null,
      timestamp: timestamp.value,
      deviceId: deviceId.value,
    );
  }

  /// Converts a Drift audit log companion back to the domain entity.
  domain.AuditLog toDomain() => toModel().toDomain();

  /// Converts a Drift audit log companion to a Drift row.
  db.AuditLog toDrift() => toModel().toDrift();
}
