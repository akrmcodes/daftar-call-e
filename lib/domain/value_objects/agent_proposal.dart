import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'agent_proposal.freezed.dart';

/// One step in a `propose_closing_plan` payload.
@freezed
abstract class ClosingPlanStep with _$ClosingPlanStep {
  const factory ClosingPlanStep({
    required String title,
    String? tool,
    String? notes,
  }) = _ClosingPlanStep;
}

/// Tool-specific proposal payload (OpenAPI `ProposalPayload`).
@freezed
sealed class AgentProposalPayload with _$AgentProposalPayload {
  const factory AgentProposalPayload.debt({
    required String contactHint,
    required int amountMinor,
    required String currencyCode,
    String? contactId,
    String? note,
    String? itemName,
    String? ledgerId,
    String? ledgerHint,
  }) = ProposeDebtPayload;

  const factory AgentProposalPayload.payment({
    required String contactHint,
    required int amountMinor,
    required String currencyCode,
    String? contactId,
    String? note,
    String? itemName,
    String? ledgerId,
    String? ledgerHint,
  }) = ProposePaymentPayload;

  const factory AgentProposalPayload.createContact({
    required String name,
    String? phone,
    String? ledgerId,
  }) = ProposeCreateContactPayload;

  const factory AgentProposalPayload.createLedger({
    required String name,
    String? type,
  }) = ProposeCreateLedgerPayload;

  const factory AgentProposalPayload.closingPlan({
    required List<ClosingPlanStep> steps,
    String? localDay,
  }) = ProposeClosingPlanPayload;

  const factory AgentProposalPayload.parseGoal({
    required String goalClass,
    double? confidence,
    String? notes,
  }) = ParseGoalPayload;

  /// Contact statement PDF (OpenAPI `ProposeStatementPayload`).
  const factory AgentProposalPayload.statement({
    @Default('') String contactId,
    String? contactHint,
    String? ledgerId,
  }) = ProposeStatementPayload;

  /// WhatsApp drafts or unknown tools — raw JSON object.
  const factory AgentProposalPayload.generic({
    required Map<String, Object?> json,
  }) = GenericProposalPayload;
}

/// Appendix J.3 proposal envelope extracted from an ADK tool response.
@freezed
abstract class AgentProposal with _$AgentProposal {
  const factory AgentProposal({
    required String proposalId,
    required ProposalTool tool,
    required AgentProposalPayload payload,
    required bool confirmRequired,
    required Map<String, Object?> rawEnvelope,
  }) = _AgentProposal;

  const AgentProposal._();
}
