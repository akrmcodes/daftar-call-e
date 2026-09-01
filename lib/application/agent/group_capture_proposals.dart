import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';

/// Tools that may be grouped into one compound capture Confirm card.
bool isCaptureBundleTool(ProposalTool tool) {
  return tool == ProposalTool.proposeCreateLedger ||
      tool == ProposalTool.proposeCreateContact ||
      tool == ProposalTool.proposeDebt ||
      tool == ProposalTool.proposePayment ||
      tool == ProposalTool.proposeStatement;
}

/// Commit order inside a capture bundle (ledger → contact → money).
int captureProposalOrder(ProposalTool tool) {
  return switch (tool) {
    ProposalTool.proposeCreateLedger => 0,
    ProposalTool.proposeCreateContact => 1,
    ProposalTool.proposeDebt ||
    ProposalTool.proposePayment ||
    ProposalTool.proposeStatement =>
      2,
    _ => 99,
  };
}

/// Returns capture proposals in commit order, preserving ADK order within a tier.
List<AgentProposal> orderCaptureProposals(List<AgentProposal> proposals) {
  final indexed = <AgentProposal, int>{
    for (var i = 0; i < proposals.length; i++) proposals[i]: i,
  };
  final capture = [
    for (final proposal in proposals)
      if (isCaptureBundleTool(proposal.tool)) proposal,
  ]..sort((a, b) {
    final byTier = captureProposalOrder(
      a.tool,
    ).compareTo(captureProposalOrder(b.tool));
    if (byTier != 0) {
      return byTier;
    }
    return indexed[a]!.compareTo(indexed[b]!);
  });
  return capture;
}

/// Whether [proposals] should render as one compound capture card.
bool shouldBundleCaptureProposals(List<AgentProposal> proposals) {
  return proposals.length >= 2;
}

/// Stable busy-state key for an in-flight bundle confirm.
String captureBundleKey(List<AgentProposal> bundle) {
  return 'capture-bundle:${bundle.map((p) => p.proposalId).join(':')}';
}

/// One list tile: compound bundle or a single proposal row.
sealed class CaptureProposalTile {
  const CaptureProposalTile();
}

/// Two or more pending capture proposals shown as one Confirm card.
final class CaptureBundleTile extends CaptureProposalTile {
  /// Creates a bundle tile.
  const CaptureBundleTile(this.proposals);

  /// Ordered proposals in the bundle.
  final List<AgentProposal> proposals;
}

/// A single proposal row (capture or non-capture).
final class CaptureSingleTile extends CaptureProposalTile {
  /// Creates a single-proposal tile.
  const CaptureSingleTile(this.proposal);

  /// Proposal for this row.
  final AgentProposal proposal;
}

/// Builds sliver rows: one bundle when 2+ pending capture tools, else singles.
List<CaptureProposalTile> buildCaptureProposalTiles({
  required List<AgentProposal> proposals,
  required Set<String> committedIds,
  required Set<String> skippedIds,
}) {
  final pendingCapture = [
    for (final proposal in proposals)
      if (isCaptureBundleTool(proposal.tool) &&
          !committedIds.contains(proposal.proposalId) &&
          !skippedIds.contains(proposal.proposalId))
        proposal,
  ];
  final ordered = orderCaptureProposals(pendingCapture);
  final bundle = shouldBundleCaptureProposals(ordered) ? ordered : null;
  final bundledIds =
      bundle?.map((proposal) => proposal.proposalId).toSet() ?? const {};
  var bundleInserted = false;

  final tiles = <CaptureProposalTile>[];
  for (final proposal in proposals) {
    if (bundledIds.contains(proposal.proposalId)) {
      if (!bundleInserted && bundle != null) {
        tiles.add(CaptureBundleTile(bundle));
        bundleInserted = true;
      }
      continue;
    }
    tiles.add(CaptureSingleTile(proposal));
  }
  return tiles;
}
