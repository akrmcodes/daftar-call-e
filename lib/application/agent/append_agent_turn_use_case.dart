import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Appends a turn to an agent session.
class AppendAgentTurnUseCase {
  /// Creates the use case.
  const AppendAgentTurnUseCase(this._agentTurnRepository);

  final AgentTurnRepository _agentTurnRepository;

  /// Persists a new turn with a generated UUID.
  Future<Either<Failure, AgentTurn>> execute({
    required String sessionId,
    required AgentTurnRole role,
    AgentTurnConfirmState confirmState = AgentTurnConfirmState.none,
    String? transcript,
    String? proposalJson,
    String? proposalId,
    String? toolName,
  }) async {
    final trimmedSessionId = sessionId.trim();
    if (trimmedSessionId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Session id is required.',
          code: 'session_id_required',
        ),
      );
    }

    final now = DateTime.now().toUtc();
    final turn = AgentTurn(
      id: UuidUtil.generate(),
      sessionId: trimmedSessionId,
      role: role,
      confirmState: confirmState,
      createdAt: now,
      updatedAt: now,
      transcript: _normalizeOptional(transcript),
      proposalJson: _normalizeOptional(proposalJson),
      proposalId: _normalizeOptional(proposalId),
      toolName: _normalizeOptional(toolName),
    );

    return _agentTurnRepository.append(turn);
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
