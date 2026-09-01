import 'package:daftar/app/router/app_routes.dart';
import 'package:daftar/app/router/onboarding_gate_notifier.dart';
import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router_provider.g.dart';

@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final gate = OnboardingGateNotifier(
    ref.watch(settingsRepositoryProvider).watchSettings(),
  );
  ref.onDispose(gate.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.homePath,
    refreshListenable: gate,
    redirect: (context, state) {
      if (!kDebugMode &&
          state.uri.path == RouteNames.preflightSmokeTestPath) {
        return RouteNames.settingsPath;
      }
      // Contest quarantine — Stage 8 sync/invite UI unreachable.
      if (AppConstants.kContestDisableMultiDeviceSync) {
        final path = state.uri.path;
        const quarantined = {
          RouteNames.syncReportPath,
          RouteNames.memberManagementPath,
          RouteNames.joinWorkspacePath,
          RouteNames.inviteCeremonyPath,
          RouteNames.inviteAcceptPath,
        };
        if (quarantined.contains(path)) {
          return RouteNames.settingsPath;
        }
      }
      return gate.redirect(state);
    },
    routes: buildAppRoutes(),
  );
}
