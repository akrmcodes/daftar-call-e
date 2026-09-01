import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/merge_conflict_model.dart';
import 'package:daftar/domain/entities/merge_conflict.dart' as domain;
import 'package:daftar/domain/enums/conflict_type.dart';

/// Seamless conversions for merge conflict domain, data, and Drift types.
extension MergeConflictDomainMapper on domain.MergeConflict {
  /// Converts a domain merge conflict to the data-layer model.
  MergeConflictModel toModel() => MergeConflictModel.fromDomain(this);

  /// Converts a domain merge conflict directly to a Drift row.
  db.MergeConflict toDrift() {
    return db.MergeConflict(
      id: id,
      entityType: entityType,
      entityId: entityId,
      conflictType: conflictType.name,
      localSnapshot: localSnapshot,
      remoteSnapshot: remoteSnapshot,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt,
      isResolved: isResolved,
    );
  }

  /// Converts a domain merge conflict to a Drift companion.
  db.MergeConflictsCompanion toCompanion() => toDrift().toCompanion(false);
}

/// Seamless conversions for generated Drift merge conflict rows.
extension MergeConflictDriftMapper on db.MergeConflict {
  /// Converts a Drift merge conflict row to the data-layer model.
  MergeConflictModel toModel() {
    return MergeConflictModel(
      id: id,
      entityType: entityType,
      entityId: entityId,
      conflictType: _parseConflictType(conflictType),
      localSnapshot: localSnapshot,
      remoteSnapshot: remoteSnapshot,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt,
      isResolved: isResolved,
    );
  }

  /// Converts a Drift merge conflict row back to the domain entity.
  domain.MergeConflict toDomain() => toModel().toDomain();

  static ConflictType _parseConflictType(String value) {
    return ConflictType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConflictType.ambiguous,
    );
  }
}
