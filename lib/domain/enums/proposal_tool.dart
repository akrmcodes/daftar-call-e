/// OpenAPI `ProposalTool` wire names (Appendix J.3).
enum ProposalTool {
  /// Classify the goal; usually `confirmRequired: false`.
  parseGoal('parse_goal'),

  /// Propose a debt transaction.
  proposeDebt('propose_debt'),

  /// Propose a payment transaction.
  proposePayment('propose_payment'),

  /// Propose creating a contact.
  proposeCreateContact('propose_create_contact'),

  /// Propose creating a ledger.
  proposeCreateLedger('propose_create_ledger'),

  /// Propose an end-of-day closing plan.
  proposeClosingPlan('propose_closing_plan'),

  /// Propose WhatsApp draft messages.
  proposeWhatsappDrafts('propose_whatsapp_drafts'),

  /// Propose a statement / PDF prepare.
  proposeStatement('propose_statement');

  const ProposalTool(this.wireName);

  /// Exact tool string on the ADK proposal envelope.
  final String wireName;

  /// Parses a wire name, or `null` if unknown.
  static ProposalTool? fromWireName(String name) {
    for (final tool in ProposalTool.values) {
      if (tool.wireName == name) {
        return tool;
      }
    }
    return null;
  }
}
