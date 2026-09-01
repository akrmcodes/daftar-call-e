import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/merge_conflict.dart' as domain;
import 'package:daftar/domain/enums/conflict_type.dart';

/// Data-layer representation of a merge conflict.
///
/// Bridges the domain `MergeConflict` entity and the generated Drift row.
class MergeConflictModel {
  /// Creates a merge conflict model.
  const MergeConflictModel({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.conflictType,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.detectedAt,
    this.resolvedAt,
    this.isResolved = false,
  });

  /// Creates a model from the domain entity.
  factory MergeConflictModel.fromDomain(domain.MergeConflict conflict) {
    return MergeConflictModel(
      id: conflict.id,
      entityType: conflict.entityType,
      entityId: conflict.entityId,
      conflictType: conflict.conflictType,
      localSnapshot: conflict.localSnapshot,
      remoteSnapshot: conflict.remoteSnapshot,
      detectedAt: conflict.detectedAt,
      resolvedAt: conflict.resolvedAt,
      isResolved: conflict.isResolved,
    );
  }

  /// Creates a model from a Drift row.
  factory MergeConflictModel.fromDrift(db.MergeConflict row) {
    return MergeConflictModel(
      id: row.id,
      entityType: row.entityType,
      entityId: row.entityId,
      conflictType: _parseConflictType(row.conflictType),
      localSnapshot: row.localSnapshot,
      remoteSnapshot: row.remoteSnapshot,
      detectedAt: row.detectedAt,
      resolvedAt: row.resolvedAt,
      isResolved: row.isResolved,
    );
  }

  /// UUID v4 primary key.
  final String id;

  /// Type of the conflicting entity.
  final String entityType;

  /// UUID of the conflicting entity.
  final String entityId;

  /// Classification of the conflict.
  final ConflictType conflictType;

  /// JSON snapshot of the local entity state.
  final String localSnapshot;

  /// JSON snapshot of the remote entity state.
  final String remoteSnapshot;

  /// UTC timestamp when the conflict was detected.
  final DateTime detectedAt;

  /// UTC timestamp when the conflict was resolved (null if unresolved).
  final DateTime? resolvedAt;

  /// Whether this conflict has been resolved.
  final bool isResolved;

  /// Converts this model back to the domain entity.
  domain.MergeConflict toDomain() {
    return domain.MergeConflict(
      id: id,
      entityType: entityType,
      entityId: entityId,
      conflictType: conflictType,
      localSnapshot: localSnapshot,
      remoteSnapshot: remoteSnapshot,
      detectedAt: detectedAt,
      resolvedAt: resolvedAt,
      isResolved: isResolved,
    );
  }

  /// Converts this model to the generated Drift row type.
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

  /// Converts this model to a Drift companion suitable for persistence.
  db.MergeConflictsCompanion toCompanion() => toDrift().toCompanion(false);

  /// Parses a [ConflictType] from the string stored in the DB.
  static ConflictType _parseConflictType(String value) {
    return ConflictType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConflictType.ambiguous,
    );
  }
}
