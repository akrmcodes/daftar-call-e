import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String freezeRule;
  late String deployWrapper;
  late String refuseScript;
  late String stage03Script;
  late String agentReadme;
  late String roadmapV3;
  late String envDart;

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
    stage03Script = File('agent/scripts/stage0_3_gcp.sh').readAsStringSync();
    agentReadme = File('agent/README.md').readAsStringSync();
    roadmapV3 = File('docs/roadmap_v3.md').readAsStringSync();
    envDart = File('lib/core/env/env.dart').readAsStringSync();
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
      expect(deployWrapper, contains('DAFTAR_CALL_E_DEPLOY'));
      expect(deployWrapper, contains('exit 2'));
      expect(deployWrapper, contains('gcloud run deploy daftar-call-e'));
      expect(deployWrapper, contains('--no-allow-unauthenticated'));
      expect(deployWrapper, contains('call-e-runner'));
      expect(deployWrapper, contains('DAFTAR_CALL_E_MIN_INSTANCES'));
      expect(deployWrapper, contains(r'--min="${_min_instances}" --max=2'));
      expect(
        deployWrapper,
        contains(
          r'--min-instances="${_min_instances}" --max-instances=2',
        ),
      );
      expect(deployWrapper, contains('gmail-smtp-app-password'));
      expect(deployWrapper, contains('calle-api-key'));
      expect(deployWrapper, contains('/calle-secrets/calle-api-key'));
      expect(deployWrapper, contains('CALLE_ALLOWLIST'));
      expect(deployWrapper, contains('CALLE_ALLOWLIST_REGION'));
      expect(deployWrapper, contains('--env-vars-file'));
      expect(RegExp(r'\+1\d{10}').hasMatch(deployWrapper), isFalse);
      expect(deployWrapper, isNot(contains('gcloud run deploy daftar-closing-agent')));
      expect(deployWrapper, isNot(contains('adk deploy')));
      expect(deployWrapper, isNot(contains('allUsers')));
      expect(deployWrapper, isNot(contains('versions access')));
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

    test('stage 0.3 script never mutates Cloud Run or prints secret payload', () {
      expect(stage03Script, contains('calle-api-key'));
      expect(stage03Script, contains('call-e-runner@'));
      expect(stage03Script, contains('check_agentic_freeze.sh'));
      expect(stage03Script, contains('gcloud secrets create'));
      expect(stage03Script, contains('akrm.codes@gmail.com'));
      expect(stage03Script, contains('daftar-call-e'));
      expect(stage03Script, isNot(contains('gcloud run deploy')));
      expect(stage03Script, isNot(contains('services update')));
      expect(stage03Script, isNot(contains('replace-traffic')));
      expect(stage03Script, isNot(contains('versions access')));
      expect(stage03Script, isNot(contains('adk deploy')));
      expect(stage03Script, isNot(contains('services enable')));
      expect(stage03Script, isNot(contains('set-iam-policy')));
      expect(
        envDart,
        isNot(
          contains(
            "defaultValue: 'https://daftar-closing-agent-1487285471.us-central1.run.app'",
          ),
        ),
      );
      expect(envDart, contains("defaultValue: ''"));
    });

    test('stage 0.4 kill switch is documented; no leaked US DID', () {
      final stage04 = File(
        'agent/scripts/stage0_4_allowlist.sh',
      ).readAsStringSync();
      final ownerOps = File(
        'docs/contest/CALLE_STAGE0_OWNER_OPS.md',
      ).readAsStringSync();
      final gitignore = File('.gitignore').readAsStringSync();

      expect(stage04, contains('calle-allow-dial'));
      expect(stage04, contains('calle-allowlist'));
      expect(stage04, contains('false'));
      expect(stage04, isNot(contains('gcloud run deploy')));
      expect(stage04, isNot(contains('versions access')));
      expect(stage04, isNot(contains('adk deploy')));

      expect(ownerOps, contains('CALLE_ALLOW_DIAL'));
      expect(ownerOps, contains('CALLE_ALLOWLIST'));
      expect(ownerOps, contains('CALLE_ALLOWLIST_REGION'));
      expect(ownerOps, contains('false'));
      expect(ownerOps, contains('exact lowercase string `true`'));
      expect(gitignore, contains('.daftar-owner-ops/'));
      expect(RegExp(r'\+1\d{10}').hasMatch(ownerOps), isFalse);
      expect(RegExp(r'\+1\d{10}').hasMatch(stage04), isFalse);
    });

    test('stage 0.5 smoke uses create_and_wait; never mutates Cloud Run', () {
      final stage05Py = File(
        'agent/scripts/stage0_5_laptop_smoke.py',
      ).readAsStringSync();
      final stage05Sh = File(
        'agent/scripts/stage0_5_laptop_smoke.sh',
      ).readAsStringSync();
      final requirements = File('agent/requirements.txt').readAsStringSync();
      final ownerOps = File(
        'docs/contest/CALLE_STAGE0_OWNER_OPS.md',
      ).readAsStringSync();

      expect(requirements, contains('calle-ai==0.7.0'));
      expect(stage05Py, contains('create_and_wait'));
      expect(stage05Py, contains('calle-ai'));
      expect(stage05Py, contains('from calle import CalleClient'));
      expect(stage05Py, contains('CALLE_ALLOW_DIAL'));
      expect(stage05Py, isNot(contains('gcloud run deploy')));
      expect(stage05Py, isNot(contains('versions access')));
      expect(stage05Sh, contains('refuse_frozen_cloud_run.sh'));
      expect(stage05Sh, contains('CALLE_ALLOW_DIAL'));
      expect(stage05Sh, isNot(contains('gcloud run deploy')));
      expect(stage05Sh, isNot(contains('versions access')));
      expect(stage05Sh, isNot(contains('adk deploy')));
      expect(RegExp(r'\+1\d{10}').hasMatch(stage05Py), isFalse);
      expect(RegExp(r'\+1\d{10}').hasMatch(stage05Sh), isFalse);
      expect(RegExp(r'\+1\d{10}').hasMatch(ownerOps), isFalse);
    });

    test('stage 1.0 Envied default is not the frozen hostname', () {
      expect(
        envDart,
        isNot(
          contains(
            "defaultValue: 'https://daftar-closing-agent-1487285471.us-central1.run.app'",
          ),
        ),
      );
      expect(envDart, contains("defaultValue: ''"));
      expect(
        freezeRule,
        contains(
          'https://daftar-closing-agent-1487285471.us-central1.run.app',
        ),
      );
    });
  });
}
