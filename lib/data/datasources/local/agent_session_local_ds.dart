import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/agent_session_mapper.dart';
import 'package:daftar/data/models/agent_session_model.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for agent-session persistence.
class AgentSessionLocalDataSource {
  /// Creates an agent-session local data source.
  AgentSessionLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Inserts a session row.
  Future<AgentSessionModel> insertSession(AgentSessionModel session) async {
    await database.into(database.agentSessions).insert(session.toDrift());
    return session;
  }

  /// Replaces columns for an existing session.
  Future<AgentSessionModel> updateSession(AgentSessionModel session) async {
    final updatedRows =
        await (database.update(database.agentSessions)
              ..where((table) => table.id.equals(session.id)))
            .write(session.toCompanion());

    if (updatedRows == 0) {
      throw StateError('Agent session not found: ${session.id}');
    }

    return session;
  }

  /// Returns a non-deleted session by [id], or null.
  Future<AgentSessionModel?> getById(String id) async {
    final row =
        await (database.select(database.agentSessions)
              ..where((table) => table.id.equals(id))
              ..where((table) => table.isDeleted.equals(false)))
            .getSingleOrNull();

    return row?.toModel();
  }

  /// Latest active non-deleted session for [mode], or null.
  Future<AgentSessionModel?> findActive(AgentSessionMode mode) async {
    final row =
        await (database.select(database.agentSessions)
              ..where(
                (table) =>
                    table.status.equals(AgentSessionStatus.active.name),
              )
              ..where((table) => table.mode.equals(mode.name))
              ..where((table) => table.isDeleted.equals(false))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.startedAt,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();

    return row?.toModel();
  }
}
