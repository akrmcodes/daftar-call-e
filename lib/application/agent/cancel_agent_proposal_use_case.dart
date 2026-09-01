import 'package:daftar/application/agent/agent_confirm_gate.dart';
import 'package:daftar/application/agent/update_agent_turn_confirm_state_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/value_objects/cancel_proposal_result.dart';
import 'package:fpdart/fpdart.dart';

/// Cancels a proposal: never writes money and never appends a journal row.
class CancelAgentProposalUseCase {
  /// Creates the use case.
  const CancelAgentProposalUseCase({
    required AgentConfirmGate confirmGate,
    required AgentTurnRepository agentTurnRepository,
    required UpdateAgentTurnConfirmStateUseCase updateConfirmStateUseCase,
  }) : _confirmGate = confirmGate,
       _agentTurnRepository = agentTurnRepository,
       _updateConfirmStateUseCase = updateConfirmStateUseCase;

  final AgentConfirmGate _confirmGate;
  final AgentTurnRepository _agentTurnRepository;
  final UpdateAgentTurnConfirmStateUseCase _updateConfirmStateUseCase;

  /// Marks [proposalId] skipped.
  Future<Either<Failure, CancelProposalResult>> execute({
    required String proposalId,
  }) async {
    final trimmedId = proposalId.trim();
    if (trimmedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Proposal id is required.',
          code: 'proposal_id_required',
        ),
      );
    }

    if (_confirmGate.isInFlight(trimmedId)) {
      return const Left(
        ValidationFailure(
          'Cannot cancel a proposal while confirm is in flight.',
          code: 'proposal_in_flight',
        ),
      );
    }

    final existing = await _agentTurnRepository.findByProposalId(trimmedId);
    if (existing.isLeft()) {
      return Left(existing.getLeft().toNullable()!);
    }
    final turn = existing.getRight().toNullable();
    if (turn == null) {
      return const Left(
        ValidationFailure(
          'Proposal turn not found.',
          code: 'proposal_not_found',
        ),
      );
    }
    if (turn.confirmState == AgentTurnConfirmState.confirmed) {
      return const Left(
        ValidationFailure(
          'Cannot cancel an already committed proposal.',
          code: 'proposal_already_committed',
        ),
      );
    }
    if (turn.confirmState == AgentTurnConfirmState.skipped) {
      return Right(CancelProposalResult(proposalId: trimmedId));
    }

    final updated = await _updateConfirmStateUseCase.execute(
      turnId: turn.id,
      confirmState: AgentTurnConfirmState.skipped,
    );
    if (updated.isLeft()) {
      return Left(updated.getLeft().toNullable()!);
    }

    return Right(CancelProposalResult(proposalId: trimmedId));
  }
}
