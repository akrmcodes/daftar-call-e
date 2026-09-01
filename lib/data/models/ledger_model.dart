import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/ledger.dart' as domain;
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:drift/drift.dart' as drift;

/// Data-layer representation of a ledger.
///
/// The model is the authoritative bridge between the domain entity and the
/// generated Drift row/companion types.
class LedgerModel {
  /// Creates a ledger data model.
  const LedgerModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isArchived = false,
    this.isUserArchived = false,
    this.carryForwardTargetLedgerId,
    this.syncVersion = 0,
  });

  /// Builds a data model from a domain entity.
  factory LedgerModel.fromDomain(domain.Ledger ledger) {
    return LedgerModel(
      id: ledger.id,
      name: ledger.name,
      type: ledger.type,
      icon: ledger.icon,
      color: ledger.color,
      sortOrder: ledger.sortOrder,
      createdAt: ledger.createdAt,
      updatedAt: ledger.updatedAt,
      isDeleted: ledger.isDeleted,
      isArchived: ledger.isArchived,
      isUserArchived: ledger.isUserArchived,
      carryForwardTargetLedgerId: ledger.carryForwardTargetLedgerId,
      syncVersion: ledger.syncVersion,
    );
  }

  /// Builds a data model from a Drift row.
  factory LedgerModel.fromDrift(db.Ledger ledger) {
    return LedgerModel(
      id: ledger.id,
      name: ledger.name,
      type: ledger.type,
      icon: ledger.icon,
      color: ledger.color,
      sortOrder: ledger.sortOrder,
      createdAt: ledger.createdAt,
      updatedAt: ledger.updatedAt,
      isDeleted: ledger.isDeleted,
      isArchived: ledger.isArchived,
      isUserArchived: ledger.isUserArchived,
      carryForwardTargetLedgerId: ledger.carryForwardTargetLedgerId,
      syncVersion: ledger.syncVersion,
    );
  }

  /// Rebuilds a model from a populated Drift companion.
  factory LedgerModel.fromCompanion(db.LedgersCompanion companion) {
    return LedgerModel(
      id: _requiredValue(companion.id, 'id'),
      name: _requiredValue(companion.name, 'name'),
      type: _requiredValue(companion.type, 'type'),
      icon: _requiredValue(companion.icon, 'icon'),
      color: _requiredValue(companion.color, 'color'),
      sortOrder: _requiredValue(companion.sortOrder, 'sortOrder'),
      createdAt: _requiredValue(companion.createdAt, 'createdAt'),
      updatedAt: _requiredValue(companion.updatedAt, 'updatedAt'),
      isDeleted: _optionalValue(companion.isDeleted, false),
      isArchived: _optionalValue(companion.isArchived, false),
      isUserArchived: _optionalValue(companion.isUserArchived, false),
      carryForwardTargetLedgerId: _optionalNullableValue(
        companion.carryForwardTargetLedgerId,
      ),
      syncVersion: _optionalValue(companion.syncVersion, 0),
    );
  }

  /// Unique identifier.
  final String id;

  /// User-visible ledger name.
  final String name;

  /// Ledger classification.
  final LedgerType type;

  /// Icon identifier used in the UI.
  final String icon;

  /// Hex color string for presentation.
  final String color;

  /// Manual sort position.
  final int sortOrder;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-update timestamp.
  final DateTime updatedAt;

  /// Soft-delete flag.
  final bool isDeleted;

  /// Archive-first import flag.
  final bool isArchived;

  final bool isUserArchived;

  final String? carryForwardTargetLedgerId;

  /// Sync conflict resolution version.
  final int syncVersion;

  /// Converts this model back to the domain entity.
  domain.Ledger toDomain() {
    return domain.Ledger(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      isUserArchived: isUserArchived,
      carryForwardTargetLedgerId: carryForwardTargetLedgerId,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to the generated Drift row type.
  db.Ledger toDrift() {
    return db.Ledger(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      isArchived: isArchived,
      isUserArchived: isUserArchived,
      carryForwardTargetLedgerId: carryForwardTargetLedgerId,
      syncVersion: syncVersion,
    );
  }

  /// Converts this model to a Drift companion suitable for persistence.
  db.LedgersCompanion toCompanion() {
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
