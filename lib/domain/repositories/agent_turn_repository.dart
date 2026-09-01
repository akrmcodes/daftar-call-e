import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:fpdart/fpdart.dart';

/// Persistence contract for agent session turns.
abstract class AgentTurnRepository {
  /// Inserts a new turn and appends an audit log.
  Future<Either<Failure, AgentTurn>> append(AgentTurn turn);

  /// Updates confirm-gate state on [turnId] and appends an audit log.
  Future<Either<Failure, AgentTurn>> updateConfirmState({
    required String turnId,
    required AgentTurnConfirmState confirmState,
  });

  /// Latest non-deleted turn for [proposalId], or [Right] `null`.
  Future<Either<Failure, AgentTurn?>> findByProposalId(String proposalId);
}
