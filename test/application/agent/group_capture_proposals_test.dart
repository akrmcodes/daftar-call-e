import 'package:daftar/application/agent/group_capture_proposals.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const debt = AgentProposal(
    proposalId: 'debt-1',
    tool: ProposalTool.proposeDebt,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.debt(
      contactHint: 'Mohamed',
      amountMinor: 40000,
      currencyCode: 'YER',
    ),
  );

  const contact = AgentProposal(
    proposalId: 'contact-1',
    tool: ProposalTool.proposeCreateContact,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.createContact(name: 'Mohamed'),
  );

  const ledger = AgentProposal(
    proposalId: 'ledger-1',
    tool: ProposalTool.proposeCreateLedger,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.createLedger(name: 'Shop'),
  );

  const plan = AgentProposal(
    proposalId: 'plan-1',
    tool: ProposalTool.proposeClosingPlan,
    confirmRequired: true,
    rawEnvelope: {},
    payload: AgentProposalPayload.closingPlan(steps: []),
  );

  test('orders ledger then contact then money regardless of ADK order', () {
    final ordered = orderCaptureProposals([debt, contact, ledger]);
    expect(ordered.map((p) => p.proposalId), ['ledger-1', 'contact-1', 'debt-1']);
  });

  test('does not bundle a single capture proposal', () {
    expect(shouldBundleCaptureProposals([debt]), isFalse);
    final tiles = buildCaptureProposalTiles(
      proposals: [debt],
      committedIds: const {},
      skippedIds: const {},
    );
    expect(tiles, hasLength(1));
    expect(tiles.single, isA<CaptureSingleTile>());
  });

  test('bundles two or more pending capture proposals into one tile', () {
    final tiles = buildCaptureProposalTiles(
      proposals: [debt, contact, ledger, plan],
      committedIds: const {},
      skippedIds: const {},
    );
    expect(tiles, hasLength(2));
    expect(tiles.first, isA<CaptureBundleTile>());
    final bundle = (tiles.first as CaptureBundleTile).proposals;
    expect(bundle.map((p) => p.proposalId), [
      'ledger-1',
      'contact-1',
      'debt-1',
    ]);
    expect(tiles.last, isA<CaptureSingleTile>());
    expect((tiles.last as CaptureSingleTile).proposal.proposalId, 'plan-1');
  });

  test('excludes closing plan from capture bundle', () {
    final pending = orderCaptureProposals([plan, debt, contact]);
    expect(pending.map((p) => p.proposalId), ['contact-1', 'debt-1']);
  });
}
