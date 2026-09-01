import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/sync_operation.dart' as domain;

/// Data-layer representation of a sync operation.
///
/// Bridges the domain `SyncOperation` entity and the generated Drift row.
class SyncOperationModel {
  /// Creates a sync operation model.
  const SyncOperationModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.deviceId,
    required this.role,
    required this.localTimestamp,
    required this.serverUpdatedAt,
    required this.opSeq,
    this.fieldDeltas,
    this.appliedAt,
  });

  /// Creates a model from the domain entity.
  factory SyncOperationModel.fromDomain(domain.SyncOperation op) {
    return SyncOperationModel(
      id: op.id,
      entityType: op.entityType,
      entityId: op.entityId,
      action: op.action,
      deviceId: op.deviceId,
      role: op.role,
      localTimestamp: op.localTimestamp,
      serverUpdatedAt: op.serverUpdatedAt,
      opSeq: op.opSeq,
      fieldDeltas: op.fieldDeltas,
    );
  }

  /// UUID v4 — same as the AuditLog id on the originating device.
  final String id;

  /// Type of entity modified ('ledger', 'contact', 'transaction').
  final String entityType;

  /// UUID of the target entity.
  final String entityId;

  /// The mutation type ('CREATE', 'UPDATE', 'DELETE').
  final String action;

  /// JSON map of changed fields → new values. Nullable.
  final String? fieldDeltas;

  /// Identifier of the device that originated this operation.
  final String deviceId;

  /// Workspace role of the user ('owner', 'editor').
  final String role;

  /// Device-local UTC timestamp when the op was created.
  final DateTime localTimestamp;

  /// Server-assigned UTC timestamp (ordering authority).
  final DateTime serverUpdatedAt;

  /// Server-assigned monotonic sequence number.
  final int opSeq;

  /// UTC timestamp when this op was applied locally.
  final DateTime? appliedAt;

  /// Converts this model back to the domain entity.
  domain.SyncOperation toDomain() {
    return domain.SyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      deviceId: deviceId,
      role: role,
      localTimestamp: localTimestamp,
      serverUpdatedAt: serverUpdatedAt,
      opSeq: opSeq,
      fieldDeltas: fieldDeltas,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.SyncOperation toDrift() {
    return db.SyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      fieldDeltas: fieldDeltas,
      deviceId: deviceId,
      role: role,
      localTimestamp: localTimestamp,
      serverUpdatedAt: serverUpdatedAt,
      opSeq: opSeq,
      appliedAt: appliedAt ?? DateTime.now().toUtc(),
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.SyncOperationsCompanion toCompanion() => toDrift().toCompanion(false);
}
