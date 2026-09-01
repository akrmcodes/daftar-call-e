import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/ledger_model.dart';
import 'package:daftar/domain/entities/ledger.dart' as domain;

/// Seamless conversions for ledger domain, data, and Drift types.
extension LedgerDomainMapper on domain.Ledger {
  /// Converts a domain ledger to the data-layer model.
  LedgerModel toModel() => LedgerModel.fromDomain(this);

  /// Converts a domain ledger directly to a Drift row.
  db.Ledger toDrift() => toModel().toDrift();

  /// Converts a domain ledger to a Drift companion.
  db.LedgersCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift ledger rows.
extension LedgerDriftMapper on db.Ledger {
  /// Converts a Drift ledger row to the data-layer model.
  LedgerModel toModel() => LedgerModel.fromDrift(this);

  /// Converts a Drift ledger row back to the domain entity.
  domain.Ledger toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift ledger companions.
extension LedgerCompanionMapper on db.LedgersCompanion {
  /// Converts a Drift ledger companion to the data-layer model.
  LedgerModel toModel() => LedgerModel.fromCompanion(this);

  /// Converts a Drift ledger companion back to the domain entity.
  domain.Ledger toDomain() => toModel().toDomain();

  /// Converts a Drift ledger companion to a Drift row.
  db.Ledger toDrift() => toModel().toDrift();
}
