import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Updates confirm-gate state on an existing agent turn.
class UpdateAgentTurnConfirmStateUseCase {
  /// Creates the use case.
  const UpdateAgentTurnConfirmStateUseCase(this._agentTurnRepository);

  final AgentTurnRepository _agentTurnRepository;

  /// Sets [confirmState] on [turnId].
  Future<Either<Failure, AgentTurn>> execute({
    required String turnId,
    required AgentTurnConfirmState confirmState,
  }) async {
    final trimmedId = turnId.trim();
    if (trimmedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Turn id is required.',
          code: 'turn_id_required',
        ),
      );
    }

    return _agentTurnRepository.updateConfirmState(
      turnId: trimmedId,
      confirmState: confirmState,
    );
  }
}
