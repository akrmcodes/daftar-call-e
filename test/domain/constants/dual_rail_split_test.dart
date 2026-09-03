import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/constants/dual_rail_split.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usPhone = '+15555550100';

  CollectionsCandidate candidate({
    required String id,
    String? phone,
    String? email,
    bool doNotCall = false,
    int ageDays = 30,
  }) {
    return CollectionsCandidate(
      contactId: id,
      name: id,
      phone: phone,
      email: email,
      ledgerId: 'ledger',
      netBalance: -500,
      currencyCode: 'YER',
      ageDays: ageDays,
      toneBand: ReminderToneBand.firm,
      doNotCall: doNotCall,
    );
  }

  DualRailSplitResult split({
    required List<CollectionsCandidate> ranked,
    Set<String>? allowlist,
    bool allowDial = true,
    String allowlistRegion = 'US',
  }) {
    return DualRailSplit.split(
      ranked: ranked,
      allowlistRegion: allowlistRegion,
      allowlist: allowlist ?? const {},
      allowDial: allowDial,
    );
  }

  test('YE with email is callUnavailable in email set not call set', () {
    final result = split(
      ranked: [
        candidate(
          id: 'ye',
          phone: '0771234567',
          email: 'ye@example.com',
        ),
      ],
      allowlist: {'+967771234567'},
    );

    expect(result.callSet, isEmpty);
    expect(result.emailSet, hasLength(1));
    expect(result.ranked.single.rail, OutreachRail.callUnavailable);
  });

  test('US NANP with email and allowlist is both', () {
    final result = split(
      ranked: [
        candidate(
          id: 'us',
          phone: usPhone,
          email: 'us@example.com',
        ),
      ],
      allowlist: {usPhone},
    );

    expect(result.callSet.single.contactId, 'us');
    expect(result.emailSet.single.contactId, 'us');
    expect(result.ranked.single.rail, OutreachRail.both);
  });

  test('six US call-eligible caps call set at 5', () {
    final ranked = [
      for (var i = 0; i < 6; i++)
        candidate(
          id: 'us-$i',
          phone: usPhone,
          email: i < 5 ? 'c$i@example.com' : null,
          ageDays: 60 - i,
        ),
    ];

    final result = split(
      ranked: ranked,
      allowlist: {usPhone},
    );

    expect(result.callSet, hasLength(5));
    expect(result.ranked[5].rail, OutreachRail.skipped);
    expect(result.ranked[4].rail, OutreachRail.both);
  });

  test('sixth call-eligible with email gets email rail only', () {
    final ranked = [
      for (var i = 0; i < 6; i++)
        candidate(
          id: 'us-$i',
          phone: usPhone,
          email: 'c$i@example.com',
          ageDays: 60 - i,
        ),
    ];

    final result = split(
      ranked: ranked,
      allowlist: {usPhone},
    );

    expect(result.callSet, hasLength(5));
    expect(result.ranked[5].rail, OutreachRail.email);
  });

  test('email-only contact is email rail not in call set', () {
    final result = split(
      ranked: [
        candidate(id: 'email-only', email: 'a@example.com'),
      ],
    );

    expect(result.callSet, isEmpty);
    expect(result.emailSet, hasLength(1));
    expect(result.ranked.single.rail, OutreachRail.email);
  });

  test('no phone and no email is skipped', () {
    final result = split(
      ranked: [candidate(id: 'ghost')],
    );

    expect(result.callSet, isEmpty);
    expect(result.emailSet, isEmpty);
    expect(result.ranked.single.rail, OutreachRail.skipped);
  });

  test('doNotCall drops from call set but keeps email', () {
    final result = split(
      ranked: [
        candidate(
          id: 'dnc',
          phone: usPhone,
          email: 'dnc@example.com',
          doNotCall: true,
        ),
      ],
      allowlist: {usPhone},
    );

    expect(result.callSet, isEmpty);
    expect(result.emailSet, hasLength(1));
    expect(result.ranked.single.rail, OutreachRail.email);
  });

  test('SA not on allowlist with email is email only', () {
    final result = split(
      ranked: [
        candidate(
          id: 'sa',
          phone: '+966 50 123 4567',
          email: 'sa@example.com',
        ),
      ],
      allowlist: {usPhone},
    );

    expect(result.callSet, isEmpty);
    expect(result.ranked.single.rail, OutreachRail.email);
    expect(result.ranked.single.phone, contains('966'));
  });

  test('email set caps at 20 and pdfTop5 is first five', () {
    final ranked = [
      for (var i = 0; i < 25; i++)
        candidate(id: '$i', email: 'c$i@example.com', ageDays: 100 - i),
    ];

    final result = split(ranked: ranked);

    expect(result.emailSet, hasLength(ClosingAgentConstants.maxEmailRecipients));
    expect(result.pdfTop5, hasLength(ClosingAgentConstants.statementSetSize));
    expect(result.pdfTop5.first.contactId, '0');
    expect(result.pdfTop5.last.contactId, '4');
  });

  test('allowDial false prevents call set membership', () {
    final result = split(
      ranked: [
        candidate(
          id: 'us',
          phone: usPhone,
          email: 'us@example.com',
        ),
      ],
      allowlist: {usPhone},
      allowDial: false,
    );

    expect(result.callSet, isEmpty);
    expect(result.ranked.single.rail, OutreachRail.email);
  });

  test('ProposeClosingPlanPayload has no contact id list', () {
    const payload = ProposeClosingPlanPayload(
      steps: [
        ClosingPlanStep(title: 'Summary'),
        ClosingPlanStep(title: 'Backup'),
        ClosingPlanStep(title: 'Aging'),
      ],
      localDay: '2026-09-03',
    );

    expect(payload.steps, hasLength(3));
    expect(payload.localDay, '2026-09-03');
  });
}
