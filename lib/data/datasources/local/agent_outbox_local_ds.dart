import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/data/mappers/agent_outbox_item_mapper.dart';
import 'package:daftar/data/models/agent_outbox_item_model.dart';
import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:drift/drift.dart' as drift;

/// Local data source for the thin agent outbox queue.
class AgentOutboxLocalDataSource {
  /// Creates an agent-outbox local data source.
  AgentOutboxLocalDataSource(this.database);

  /// Drift database dependency.
  final db.AppDatabase database;

  /// Inserts an outbox row.
  Future<AgentOutboxItemModel> insertItem(AgentOutboxItemModel item) async {
    await database.into(database.agentOutboxRows).insert(item.toDrift());
    return item;
  }

  /// Returns queued/retrying rows whose retry time is due.
  Future<List<AgentOutboxItemModel>> listPending() async {
    final now = DateTime.now().toUtc();
    final rows =
        await (database.select(database.agentOutboxRows)
              ..where(
                (table) => table.status.isIn([
                  AgentOutboxStatus.queued.name,
                  AgentOutboxStatus.retrying.name,
                ]),
              )
              ..where(
                (table) =>
                    table.nextRetryAt.isNull() |
                    table.nextRetryAt.isSmallerOrEqualValue(now),
              )
              ..orderBy([
                (table) => drift.OrderingTerm(expression: table.createdAt),
                (table) => drift.OrderingTerm(expression: table.id),
              ]))
            .get();

    return rows.map((row) => row.toModel()).toList(growable: false);
  }
}
