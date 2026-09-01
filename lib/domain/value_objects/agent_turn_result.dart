import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_turn_result.freezed.dart';

/// Parsed result of one `POST /run` turn.
@freezed
abstract class AgentTurnResult with _$AgentTurnResult {
  const factory AgentTurnResult({
    required String correlationId,
    required String sessionId,
    required List<AgentProposal> proposals,
    String? narrative,
    String? modelId,
    @Default(<String>[]) List<String> toolNames,
    int? latencyMs,
  }) = _AgentTurnResult;
}
