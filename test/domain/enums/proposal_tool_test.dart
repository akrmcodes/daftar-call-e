import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gate 4 / Appendix J catalog. A ninth [ProposalTool] fails this freeze (§5.3).
const frozenProposalTools = {
  'parse_goal',
  'propose_debt',
  'propose_payment',
  'propose_create_contact',
  'propose_create_ledger',
  'propose_closing_plan',
  'propose_whatsapp_drafts',
  'propose_statement',
};

void main() {
  test('ProposalTool wire names stay frozen to the Gate 4 catalog', () {
    final wires = ProposalTool.values.map((tool) => tool.wireName).toSet();
    expect(ProposalTool.values, hasLength(8));
    expect(wires, frozenProposalTools);
  });

  test('fromWireName round-trips every frozen tool and rejects unknowns', () {
    for (final tool in ProposalTool.values) {
      expect(ProposalTool.fromWireName(tool.wireName), tool);
    }
    expect(ProposalTool.fromWireName('propose_send_email'), isNull);
    expect(ProposalTool.fromWireName(''), isNull);
  });
}
