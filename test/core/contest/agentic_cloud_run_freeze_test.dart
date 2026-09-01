import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String freezeRule;
  late String deployWrapper;
  late String refuseScript;
  late String agentReadme;
  late String roadmapV3;

  setUpAll(() {
    freezeRule = File(
      '.cursor/rules/calle-agentic-freeze.mdc',
    ).readAsStringSync();
    deployWrapper = File(
      'agent/scripts/deploy_daftar_call_e.sh',
    ).readAsStringSync();
    refuseScript = File(
      'agent/scripts/refuse_frozen_cloud_run.sh',
    ).readAsStringSync();
    agentReadme = File('agent/README.md').readAsStringSync();
    roadmapV3 = File('docs/roadmap_v3.md').readAsStringSync();
  });

  group('Agentic Cloud Run freeze (file checks)', () {
    test('freeze rule names frozen URL and forbids deploy', () {
      expect(
        freezeRule,
        contains(
          'https://daftar-closing-agent-1487285471.us-central1.run.app',
        ),
      );
      expect(freezeRule, contains('gcloud run deploy daftar-closing-agent'));
      expect(freezeRule.toLowerCase(), contains('never'));
      expect(freezeRule, contains('alwaysApply: true'));
    });

    test('deploy wrapper aborts on service name, origin, and frozen URL', () {
      expect(deployWrapper, contains('daftar-call-e'));
      expect(deployWrapper, contains('daftar-closing-agent.git'));
      expect(deployWrapper, contains('daftar-closing-agent-1487285471'));
      expect(deployWrapper, contains('require explicit service daftar-call-e'));
      expect(deployWrapper, contains('Stage 1 not started'));
      expect(deployWrapper, contains('exit 2'));
      expect(refuseScript, contains('daftar-call-e'));
      expect(refuseScript, contains('daftar-closing-agent.git'));
      expect(refuseScript, contains('daftar-closing-agent-1487285471'));
    });

    test('agent README freeze banner precedes daftar-closing-agent deploy', () {
      final banner = agentReadme.indexOf(
        'DO NOT RUN — frozen All Things Agentic',
      );
      final frozenWord = agentReadme.indexOf('frozen All Things Agentic');
      final deploy = agentReadme.indexOf(
        'gcloud run deploy daftar-closing-agent',
      );
      expect(
        banner,
        greaterThanOrEqualTo(0),
        reason: 'missing DO NOT RUN banner',
      );
      expect(frozenWord, greaterThanOrEqualTo(0));
      expect(
        deploy,
        greaterThan(banner),
        reason: 'deploy command before freeze banner',
      );
      expect(agentReadme, contains('HISTORICAL — do not execute'));
      expect(agentReadme, contains('scripts/deploy_daftar_call_e.sh'));
      expect(agentReadme, contains('docs/roadmap_v3.md'));
    });

    test('roadmap v3 still forbids redeploying the frozen URL', () {
      expect(
        roadmapV3,
        contains(
          'https://daftar-closing-agent-1487285471.us-central1.run.app',
        ),
      );
      expect(
        roadmapV3.toLowerCase(),
        contains('do not redeploy'),
      );
    });
  });
}
