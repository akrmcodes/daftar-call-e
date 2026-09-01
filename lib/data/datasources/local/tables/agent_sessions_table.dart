import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:drift/drift.dart';

/// Mutable Closing Agent / capture session row.
@TableIndex(name: 'idx_agent_sessions_status', columns: {#status})
@TableIndex(name: 'idx_agent_sessions_started_at', columns: {#startedAt})
class AgentSessions extends Table {
  /// UUID v4 primary key.
  TextColumn get id => text()();

  /// Capture vs closing.
  TextColumn get mode => textEnum<AgentSessionMode>()();

  /// Active / completed / cancelled.
  TextColumn get status => textEnum<AgentSessionStatus>()();

  /// UTC session start.
  DateTimeColumn get startedAt => dateTime()();

  /// UTC session end, if finished.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Optional correlation id shared with Cloud Run logs.
  TextColumn get correlationId => text().nullable()();

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
