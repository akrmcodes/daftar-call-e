import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_turn_model.dart';
import 'package:daftar/domain/entities/agent_turn.dart' as domain;

/// Seamless conversions for agent-turn domain, data, and Drift types.
extension AgentTurnDomainMapper on domain.AgentTurn {
  /// Converts a domain turn to the data-layer model.
  AgentTurnModel toModel() => AgentTurnModel.fromDomain(this);

  /// Converts a domain turn directly to a Drift row.
  db.AgentTurn toDrift() => toModel().toDrift();

  /// Converts a domain turn to a Drift companion.
  db.AgentTurnsCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift agent-turn rows.
extension AgentTurnDriftMapper on db.AgentTurn {
  /// Converts a Drift row to the data-layer model.
  AgentTurnModel toModel() => AgentTurnModel.fromDrift(this);

  /// Converts a Drift row back to the domain entity.
  domain.AgentTurn toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift agent-turn companions.
extension AgentTurnCompanionMapper on db.AgentTurnsCompanion {
  /// Converts a Drift companion to the data-layer model.
  AgentTurnModel toModel() => AgentTurnModel.fromCompanion(this);

  /// Converts a Drift companion back to the domain entity.
  domain.AgentTurn toDomain() => toModel().toDomain();

  /// Converts a Drift companion to a Drift row.
  db.AgentTurn toDrift() => toModel().toDrift();
}
