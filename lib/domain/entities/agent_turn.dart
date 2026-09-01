import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_turn.freezed.dart';

/// One turn inside an agent session.
@freezed
abstract class AgentTurn with _$AgentTurn {
  const factory AgentTurn({
    required String id,
    required String sessionId,
    required AgentTurnRole role,
    required AgentTurnConfirmState confirmState,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? transcript,
    String? proposalJson,
    String? proposalId,
    String? toolName,
    @Default(false) bool isDeleted,
    @Default(0) int syncVersion,
  }) = _AgentTurn;
}
