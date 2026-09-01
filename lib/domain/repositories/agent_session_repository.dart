import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:fpdart/fpdart.dart';

/// Persistence contract for agent sessions.
abstract class AgentSessionRepository {
  /// Inserts a new session and appends an audit log.
  Future<Either<Failure, AgentSession>> create(AgentSession session);

  /// Marks [sessionId] as [status] (`completed` or `cancelled`) and sets
  /// `endedAt`.
  Future<Either<Failure, AgentSession>> complete({
    required String sessionId,
    required AgentSessionStatus status,
  });

  /// Returns the session by [id], or [Left] if missing / soft-deleted.
  Future<Either<Failure, AgentSession>> getById(String id);

  /// Most recently started active session for [mode], or [Right] `null`.
  Future<Either<Failure, AgentSession?>> findActive({
    required AgentSessionMode mode,
  });
}
