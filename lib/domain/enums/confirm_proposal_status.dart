/// OpenAPI `ConfirmProposalResult.status` (device confirm gate).
enum ConfirmProposalStatus {
  /// Confirm-state persisted (money writes land in Stage 2.3).
  committed,

  /// This `proposalId` was already confirmed — no second write.
  noopAlreadyCommitted,

  /// Another confirm for the same `proposalId` is in flight.
  rejectedInFlight,

  /// Confirm rejected by validation (unused when the use case returns Left).
  rejectedValidation,
}
