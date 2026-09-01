import 'package:daftar/data/mappers/adk_event_proposal_mapper.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _debtEvent({required Object amountMinor}) {
  return <String, Object?>{
    'content': <String, Object?>{
      'role': 'model',
      'parts': <Object?>[
        <String, Object?>{
          'functionResponse': <String, Object?>{
            'name': 'propose_debt',
            'response': <String, Object?>{
              'proposalId': '11111111-1111-4111-8111-111111111111',
              'tool': 'propose_debt',
              'payload': <String, Object?>{
                'contactHint': 'Mohamed',
                'amountMinor': amountMinor,
                'currencyCode': 'YER',
              },
              'confirmRequired': true,
            },
          },
        },
      ],
    },
  };
}

void main() {
  group('extractProposalsFromAdkEvents', () {
    test('maps two functionResponse parts in one event, order preserved', () {
      final proposals = extractProposalsFromAdkEvents([
        <String, Object?>{
          'content': <String, Object?>{
            'role': 'model',
            'parts': <Object?>[
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'name': 'propose_debt',
                  'response': <String, Object?>{
                    'proposalId': '11111111-1111-4111-8111-111111111111',
                    'tool': 'propose_debt',
                    'payload': <String, Object?>{
                      'contactHint': 'Ahmed',
                      'amountMinor': 500,
                      'currencyCode': 'YER',
                    },
                    'confirmRequired': true,
                  },
                },
              },
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'name': 'propose_debt',
                  'response': <String, Object?>{
                    'proposalId': '22222222-2222-4222-8222-222222222222',
                    'tool': 'propose_debt',
                    'payload': <String, Object?>{
                      'contactHint': 'Mohamed',
                      'amountMinor': 300,
                      'currencyCode': 'YER',
                    },
                    'confirmRequired': true,
                  },
                },
              },
            ],
          },
        },
      ]);

      expect(proposals, hasLength(2));
      expect(proposals[0].proposalId, '11111111-1111-4111-8111-111111111111');
      expect(proposals[1].proposalId, '22222222-2222-4222-8222-222222222222');
      expect(
        proposals[0].payload,
        const AgentProposalPayload.debt(
          contactHint: 'Ahmed',
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      );
      expect(
        proposals[1].payload,
        const AgentProposalPayload.debt(
          contactHint: 'Mohamed',
          amountMinor: 300,
          currencyCode: 'YER',
        ),
      );
    });

    test('maps propose_debt with integer amountMinor 500', () {
      final proposals = extractProposalsFromAdkEvents([
        _debtEvent(amountMinor: 500),
      ]);

      expect(proposals, hasLength(1));
      final proposal = proposals.single;
      expect(proposal.proposalId, '11111111-1111-4111-8111-111111111111');
      expect(proposal.tool, ProposalTool.proposeDebt);
      expect(proposal.confirmRequired, isTrue);
      expect(
        proposal.payload,
        const AgentProposalPayload.debt(
          contactHint: 'Mohamed',
          amountMinor: 500,
          currencyCode: 'YER',
        ),
      );
    });

    test('maps propose_debt itemName and note', () {
      final event = _debtEvent(amountMinor: 500);
      final content = event['content']! as Map<String, Object?>;
      final parts = content['parts']! as List<Object?>;
      final part = parts.single! as Map<String, Object?>;
      final functionResponse =
          part['functionResponse']! as Map<String, Object?>;
      final response = functionResponse['response']! as Map<String, Object?>;
      final payload = response['payload']! as Map<String, Object?>;
      payload['itemName'] = 'juice';
      payload['note'] = 'he will pay Friday';

      final proposals = extractProposalsFromAdkEvents([event]);
      expect(
        proposals.single.payload,
        const AgentProposalPayload.debt(
          contactHint: 'Mohamed',
          amountMinor: 500,
          currencyCode: 'YER',
          itemName: 'juice',
          note: 'he will pay Friday',
        ),
      );
    });

    test('rejects amountMinor 500.0 (double)', () {
      expect(
        () => extractProposalsFromAdkEvents([_debtEvent(amountMinor: 500.0)]),
        throwsA(
          isA<ProposalParseException>().having(
            (error) => error.code,
            'code',
            'invalid_amount_minor',
          ),
        ),
      );
    });

    test('rejects amountMinor "500" (string)', () {
      expect(
        () => extractProposalsFromAdkEvents([_debtEvent(amountMinor: '500')]),
        throwsA(
          isA<ProposalParseException>().having(
            (error) => error.code,
            'code',
            'invalid_amount_minor',
          ),
        ),
      );
    });

    test('maps propose_statement to ProposeStatementPayload', () {
      final proposals = extractProposalsFromAdkEvents([
        <String, Object?>{
          'content': <String, Object?>{
            'role': 'model',
            'parts': <Object?>[
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'name': 'propose_statement',
                  'response': <String, Object?>{
                    'proposalId': '22222222-2222-4222-8222-222222222222',
                    'tool': 'propose_statement',
                    'payload': <String, Object?>{
                      'contactId': 'contact-1',
                      'contactHint': 'Mohamed',
                      'ledgerId': 'ledger-1',
                    },
                    'confirmRequired': true,
                  },
                },
              },
            ],
          },
        },
      ]);

      expect(proposals, hasLength(1));
      final proposal = proposals.single;
      expect(proposal.tool, ProposalTool.proposeStatement);
      expect(proposal.confirmRequired, isTrue);
      expect(
        proposal.payload,
        const AgentProposalPayload.statement(
          contactId: 'contact-1',
          contactHint: 'Mohamed',
          ledgerId: 'ledger-1',
        ),
      );
    });

    test('maps propose_statement with missing contactId to empty string', () {
      final proposals = extractProposalsFromAdkEvents([
        <String, Object?>{
          'content': <String, Object?>{
            'role': 'model',
            'parts': <Object?>[
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'name': 'propose_statement',
                  'response': <String, Object?>{
                    'proposalId': '33333333-3333-4333-8333-333333333333',
                    'tool': 'propose_statement',
                    'payload': <String, Object?>{},
                    'confirmRequired': true,
                  },
                },
              },
            ],
          },
        },
      ]);

      expect(
        proposals.single.payload,
        const AgentProposalPayload.statement(),
      );
    });
  });
}
