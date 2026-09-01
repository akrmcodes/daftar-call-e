/// Who produced an agent-session turn.
enum AgentTurnRole {
  /// Merchant utterance or typed goal.
  user,

  /// Model / agent response.
  agent,

  /// Tool call or tool result.
  tool,
}
