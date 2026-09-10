import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _disclosurePath = 'docs/CONTEST_DISCLOSURE.md';

const _frozenTools = [
  'parse_goal',
  'propose_debt',
  'propose_payment',
  'propose_create_contact',
  'propose_create_ledger',
  'propose_closing_plan',
  'propose_whatsapp_drafts',
  'propose_statement',
];

void main() {
  late String text;

  setUpAll(() {
    text = File(_disclosurePath).readAsStringSync();
  });

  String section(String start, String end) {
    final from = text.indexOf(start);
    final to = text.indexOf(end);
    expect(from, greaterThanOrEqualTo(0), reason: 'missing $start');
    expect(to, greaterThan(from), reason: 'missing $end after $start');
    return text.substring(from, to);
  }

  group('Stage 0.0 CONTEST_DISCLOSURE.md accuracy', () {
    test('as-of date is the Stage 6.2 final', () {
      expect(text, contains('**Date:** 2026-09-10 (final)'));
      expect(text, contains('**v3.5**'));
    });

    test('binds CALL-E Official Rules New & Existing and roadmap v3', () {
      expect(text, contains('call-e.devpost.com/rules'));
      expect(text, contains('New & Existing'));
      expect(text, contains('roadmap_v3'));
      expect(text, isNot(contains('New Projects Only')));
    });

    test('names all eight frozen FunctionTools', () {
      for (final name in _frozenTools) {
        expect(text, contains(name), reason: 'missing tool $name');
      }
    });

    test('Stage 8 kill-switch is disclosed', () {
      expect(text, contains('kContestDisableMultiDeviceSync'));
    });

    test('dual-rail CTAs: Confirm & Call and Confirm & Send Statements', () {
      expect(text, contains('Confirm & Call'));
      expect(text, contains('Confirm & Send Statements'));
    });

    test('frozen Agentic hostname is prior work, not the CALL-E service', () {
      const host = 'daftar-closing-agent-1487285471.us-central1.run.app';
      expect(text, contains(host));
      expect(text, contains('daftar-call-e'));
      final prior = section(
        '## Prior work — All Things Agentic (Aug 2026)',
        '## CALL-E contest-new (this submission)',
      );
      expect(prior, contains(host));
      final calleNew = section(
        '## CALL-E contest-new (this submission)',
        '## What we are submitting',
      );
      expect(calleNew, isNot(contains(host)));
      expect(text.toLowerCase(), contains('frozen'));
    });

    test('Hybrid E is contest leftover, not labeled substrate', () {
      expect(text, isNot(contains('Leftover substrate')));
      final hybridLine = text
          .split('\n')
          .firstWhere(
            (line) => line.contains('Hybrid E'),
            orElse: () => '',
          );
      expect(hybridLine, isNotEmpty, reason: 'Hybrid E row missing');
      expect(
        hybridLine.toLowerCase().contains('substrate'),
        isFalse,
        reason: 'Hybrid E row must not call leftover contest work substrate',
      );
      expect(
        hybridLine.toLowerCase().contains('contest-period leftover'),
        isTrue,
        reason: 'Hybrid E must be classified as contest-period leftover',
      );
    });

    test('pre-existing substrate table still lists whatsapp_util', () {
      final substrate = section(
        '## Pre-existing substrate',
        '## Prior work — All Things Agentic (Aug 2026)',
      );
      expect(substrate, contains('whatsapp_util'));
    });

    test('CALL-E-new runtime is Landed; skill PR is Opened not merged', () {
      final calleNew = section(
        '## CALL-E contest-new (this submission)',
        '## What we are submitting',
      );
      expect(calleNew, contains('Confirm & Call'));
      expect(calleNew, contains('agent/calls/'));
      expect(calleNew, contains('| Confirm & Call |'));
      expect(calleNew, contains('**Landed** (Stages 1–5)'));
      expect(calleNew, contains('| Schema 26 |'));
      expect(calleNew, contains('**Landed** (Stage 2.1)'));
      expect(calleNew, contains('not this bucket'));
      expect(calleNew, isNot(contains('**Planned** (Stages 1–4)')));
      expect(calleNew, contains('**Opened**'));
      expect(calleNew.toLowerCase(), isNot(contains('not landed as of')));
    });

    test('discloses owner-answered Callcentric DID; no live E.164', () {
      expect(text, contains('owns and answers'));
      expect(text, contains('Callcentric'));
      expect(text, contains('Linphone'));
      expect(RegExp(r'\+1\d{10}').hasMatch(text), isFalse);
    });
  });
}
