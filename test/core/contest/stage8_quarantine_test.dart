import 'dart:io';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('§7.1 Stage 8 contest quarantine', () {
    test('kill-switch is on for this build', () {
      expect(AppConstants.kContestDisableMultiDeviceSync, isTrue);
    });

    test('router redirects exactly the five Stage 8 UI paths', () {
      final source =
          File('lib/app/router/app_router_provider.dart').readAsStringSync();
      expect(source.contains('kContestDisableMultiDeviceSync'), isTrue);

      final block = RegExp(
        r'const quarantined = \{([^}]+)\}',
        dotAll: true,
      ).firstMatch(source);
      expect(block, isNotNull, reason: 'router must declare quarantined paths');

      final names = RegExp(r'RouteNames\.(\w+)')
          .allMatches(block!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
      expect(names, {
        'syncReportPath',
        'memberManagementPath',
        'joinWorkspacePath',
        'inviteCeremonyPath',
        'inviteAcceptPath',
      });
      expect(RouteNames.syncReportPath, '/settings/sync-report');
      expect(RouteNames.memberManagementPath, '/settings/members');
      expect(RouteNames.joinWorkspacePath, '/settings/join-workspace');
      expect(RouteNames.inviteCeremonyPath, '/invite/ceremony');
      expect(RouteNames.inviteAcceptPath, '/invite/accept');
    });

    test('settings hides Join Workspace when the kill-switch is on', () {
      final source = File(
        'lib/presentation/screens/settings/settings_screen.dart',
      ).readAsStringSync();
      expect(
        source,
        contains(
          'const showJoinWorkspace = !AppConstants.kContestDisableMultiDeviceSync;',
        ),
      );
    });

    test('main.dart never starts sync or deep-link engines when quarantined', () {
      final source = File('lib/main.dart').readAsStringSync();

      bool engineReturnsWhenQuarantined(String functionName) {
        final fn = RegExp(
          '$functionName\\(\\) async \\{([\\s\\S]*?)^}',
          multiLine: true,
        ).firstMatch(source);
        if (fn == null) {
          return false;
        }
        final body = fn.group(1)!;
        return RegExp(
          r'if \(AppConstants\.kContestDisableMultiDeviceSync\) \{\s*return;',
        ).hasMatch(body);
      }

      expect(engineReturnsWhenQuarantined('_startDeepLinkListener'), isTrue);
      expect(engineReturnsWhenQuarantined('_startSyncEngine'), isTrue);
    });
  });
}
