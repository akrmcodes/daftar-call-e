import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/agent_turn_mapper.dart';
import 'package:daftar/data/models/agent_turn_model.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for agent-turn persistence.
class AgentTurnLocalDataSource {
  /// Creates an agent-turn local data source.
  AgentTurnLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Inserts a turn row.
  Future<AgentTurnModel> insertTurn(AgentTurnModel turn) async {
    await database.into(database.agentTurns).insert(turn.toDrift());
    return turn;
  }

  /// Replaces columns for an existing turn.
  Future<AgentTurnModel> updateTurn(AgentTurnModel turn) async {
    final updatedRows = await (database.update(
      database.agentTurns,
    )..where((table) => table.id.equals(turn.id))).write(turn.toCompanion());

    if (updatedRows == 0) {
      throw StateError('Agent turn not found: ${turn.id}');
    }

    return turn;
  }

  /// Returns a non-deleted turn by [id], or null.
  Future<AgentTurnModel?> getById(String id) async {
    final row =
        await (database.select(database.agentTurns)
              ..where((table) => table.id.equals(id))
              ..where((table) => table.isDeleted.equals(false)))
            .getSingleOrNull();

    return row?.toModel();
  }

  /// Latest non-deleted turn for [proposalId], or null.
  Future<AgentTurnModel?> getByProposalId(String proposalId) async {
    final row =
        await (database.select(database.agentTurns)
              ..where((table) => table.proposalId.equals(proposalId))
              ..where((table) => table.isDeleted.equals(false))
              ..orderBy([
                (table) => drift.OrderingTerm(
                  expression: table.createdAt,
                  mode: drift.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();

    return row?.toModel();
  }
}
