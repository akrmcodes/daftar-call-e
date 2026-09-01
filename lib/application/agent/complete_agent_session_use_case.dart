import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Completes or cancels an agent session.
class CompleteAgentSessionUseCase {
  /// Creates the use case.
  const CompleteAgentSessionUseCase(this._agentSessionRepository);

  final AgentSessionRepository _agentSessionRepository;

  /// Sets [status] to `completed` or `cancelled` and records `endedAt`.
  Future<Either<Failure, AgentSession>> execute({
    required String sessionId,
    AgentSessionStatus status = AgentSessionStatus.completed,
  }) async {
    final trimmedId = sessionId.trim();
    if (trimmedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Session id is required.',
          code: 'session_id_required',
        ),
      );
    }

    if (status == AgentSessionStatus.active) {
      return const Left(
        ValidationFailure(
          'Session cannot be completed as active.',
          code: 'invalid_session_status',
        ),
      );
    }

    return _agentSessionRepository.complete(
      sessionId: trimmedId,
      status: status,
    );
  }
}
