import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/sync_operation_model.dart';
import 'package:daftar/domain/entities/sync_operation.dart' as domain;

/// Seamless conversions for sync operation domain, data, and Drift types.
extension SyncOperationDomainMapper on domain.SyncOperation {
  /// Converts a domain sync operation to the data-layer model.
  SyncOperationModel toModel() => SyncOperationModel.fromDomain(this);

  /// Converts a domain sync operation directly to a Drift row.
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
      appliedAt: DateTime.now().toUtc(),
    );
  }

  /// Converts a domain sync operation to a Drift companion.
  db.SyncOperationsCompanion toCompanion() => toDrift().toCompanion(false);
}

/// Seamless conversions for generated Drift sync operation rows.
extension SyncOperationDriftMapper on db.SyncOperation {
  /// Converts a Drift sync operation row to the data-layer model.
  SyncOperationModel toModel() {
    return SyncOperationModel(
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
      appliedAt: appliedAt,
    );
  }

  /// Converts a Drift sync operation row back to the domain entity.
  domain.SyncOperation toDomain() => toModel().toDomain();
}
