import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_outbox_item_model.dart';
import 'package:daftar/domain/entities/agent_outbox_item.dart' as domain;

/// Seamless conversions for agent-outbox domain, data, and Drift types.
extension AgentOutboxItemDomainMapper on domain.AgentOutboxItem {
  /// Converts a domain item to the data-layer model.
  AgentOutboxItemModel toModel() => AgentOutboxItemModel.fromDomain(this);

  /// Converts a domain item directly to a Drift row.
  db.AgentOutboxRow toDrift() => toModel().toDrift();

  /// Converts a domain item to a Drift companion.
  db.AgentOutboxRowsCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift agent-outbox rows.
extension AgentOutboxRowDriftMapper on db.AgentOutboxRow {
  /// Converts a Drift row to the data-layer model.
  AgentOutboxItemModel toModel() => AgentOutboxItemModel.fromDrift(this);

  /// Converts a Drift row back to the domain entity.
  domain.AgentOutboxItem toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift agent-outbox companions.
extension AgentOutboxRowCompanionMapper on db.AgentOutboxRowsCompanion {
  /// Converts a Drift companion to the data-layer model.
  AgentOutboxItemModel toModel() => AgentOutboxItemModel.fromCompanion(this);

  /// Converts a Drift companion back to the domain entity.
  domain.AgentOutboxItem toDomain() => toModel().toDomain();

  /// Converts a Drift companion to a Drift row.
  db.AgentOutboxRow toDrift() => toModel().toDrift();
}
