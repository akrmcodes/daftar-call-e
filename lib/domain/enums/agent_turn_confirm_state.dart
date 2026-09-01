/// Confirm-gate state attached to a turn that may carry a proposal.
enum AgentTurnConfirmState {
  /// No proposal, or confirm is not applicable.
  none,

  /// Proposal is waiting for merchant confirm / cancel.
  pending,

  /// Merchant confirmed; money write (if any) went through existing use cases.
  confirmed,

  /// Merchant skipped or cancelled; no money write.
  skipped,
}
