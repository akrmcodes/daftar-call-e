import 'package:daftar/data/datasources/local/tables/agent_sessions_table.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:drift/drift.dart';

/// Mutable turn within an [AgentSessions] row.
@TableIndex(name: 'idx_agent_turns_session', columns: {#sessionId})
@TableIndex(name: 'idx_agent_turns_proposal', columns: {#proposalId})
@TableIndex(name: 'idx_agent_turns_created_at', columns: {#createdAt})
class AgentTurns extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// FK to the parent [AgentSessions] table.
  TextColumn get sessionId => text().references(AgentSessions, #id)();

  /// Who produced this turn.
  TextColumn get role => textEnum<AgentTurnRole>()();

  /// Optional transcript text.
  TextColumn get transcript => text().nullable()();

  /// Optional proposal JSON snapshot.
  TextColumn get proposalJson => text().nullable()();

  /// Confirm-gate state for this turn.
  TextColumn get confirmState => textEnum<AgentTurnConfirmState>()();

  /// Optional confirm-gate proposal id.
  TextColumn get proposalId => text().nullable()();

  /// Optional tool name when [role] is tool.
  TextColumn get toolName => text().nullable()();

  /// UTC timestamp of creation.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// UTC timestamp of last modification.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft-delete flag.
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// Version counter for sync conflict resolution.
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
