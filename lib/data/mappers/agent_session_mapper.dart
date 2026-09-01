import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/models/agent_session_model.dart';
import 'package:daftar/domain/entities/agent_session.dart' as domain;

/// Seamless conversions for agent-session domain, data, and Drift types.
extension AgentSessionDomainMapper on domain.AgentSession {
  /// Converts a domain session to the data-layer model.
  AgentSessionModel toModel() => AgentSessionModel.fromDomain(this);

  /// Converts a domain session directly to a Drift row.
  db.AgentSession toDrift() => toModel().toDrift();

  /// Converts a domain session to a Drift companion.
  db.AgentSessionsCompanion toCompanion() => toModel().toCompanion();
}

/// Seamless conversions for generated Drift agent-session rows.
extension AgentSessionDriftMapper on db.AgentSession {
  /// Converts a Drift row to the data-layer model.
  AgentSessionModel toModel() => AgentSessionModel.fromDrift(this);

  /// Converts a Drift row back to the domain entity.
  domain.AgentSession toDomain() => toModel().toDomain();
}

/// Seamless conversions for generated Drift agent-session companions.
extension AgentSessionCompanionMapper on db.AgentSessionsCompanion {
  /// Converts a Drift companion to the data-layer model.
  AgentSessionModel toModel() => AgentSessionModel.fromCompanion(this);

  /// Converts a Drift companion back to the domain entity.
  domain.AgentSession toDomain() => toModel().toDomain();

  /// Converts a Drift companion to a Drift row.
  db.AgentSession toDrift() => toModel().toDrift();
}
