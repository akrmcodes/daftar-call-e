import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Starts an agent capture or closing session.
class StartAgentSessionUseCase {
  /// Creates the use case.
  const StartAgentSessionUseCase(this._agentSessionRepository);

  final AgentSessionRepository _agentSessionRepository;

  /// Creates an `active` session with a new UUID.
  Future<Either<Failure, AgentSession>> execute({
    required AgentSessionMode mode,
    String? correlationId,
  }) async {
    final now = DateTime.now().toUtc();
    final trimmedCorrelation = correlationId?.trim();
    final session = AgentSession(
      id: UuidUtil.generate(),
      mode: mode,
      status: AgentSessionStatus.active,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
      correlationId: (trimmedCorrelation == null || trimmedCorrelation.isEmpty)
          ? null
          : trimmedCorrelation,
    );

    return _agentSessionRepository.create(session);
  }
}
