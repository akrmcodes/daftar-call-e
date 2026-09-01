import 'package:daftar/domain/enums/agent_outbox_status.dart';
import 'package:drift/drift.dart';

/// Thin local agent outbox (offline pending runs). Processors land in Stage 5.
///
/// SQL table name is `agent_outbox`. Row class is `AgentOutboxRow`.
@TableIndex(
  name: 'idx_agent_outbox_status_next',
  columns: {#status, #nextRetryAt},
)
class AgentOutboxRows extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Queue kind (e.g. `pending_run`). String so Stage 5 can add kinds
  /// without a schema bump.
  TextColumn get kind => text()();

  /// queued / retrying / failed / done.
  TextColumn get status => textEnum<AgentOutboxStatus>()();

  /// JSON payload for the queued work.
  TextColumn get payloadJson => text()();

  /// Number of processing attempts so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Earliest UTC time the scheduler may attempt again.
  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  /// UTC timestamp of creation.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  String get tableName => 'agent_outbox';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
