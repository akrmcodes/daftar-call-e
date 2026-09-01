import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/presentation/screens/archive_vault/archive_vault_screen.dart';
import 'package:daftar/presentation/screens/closing_agent/closing_agent_screen.dart';
import 'package:daftar/presentation/screens/contact/contact_detail_screen.dart';
import 'package:daftar/presentation/screens/home/home_screen.dart';
import 'package:daftar/presentation/screens/invite/expired_invite_ceremony_screen.dart';
import 'package:daftar/presentation/screens/invite/invite_accept_handoff_screen.dart';
import 'package:daftar/presentation/screens/invite/join_workspace_screen.dart';
import 'package:daftar/presentation/screens/ledger/ledger_detail_screen.dart';
import 'package:daftar/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:daftar/presentation/screens/premium/activation_screen.dart';
import 'package:daftar/presentation/screens/settings/account_management_screen.dart';
import 'package:daftar/presentation/screens/settings/backup/backup_screen.dart';
import 'package:daftar/presentation/screens/settings/import_csv_screen.dart';
import 'package:daftar/presentation/screens/settings/member_management_screen.dart';
import 'package:daftar/presentation/screens/settings/merchant_branding_screen.dart';
import 'package:daftar/presentation/screens/settings/preflight_smoke_test_screen.dart';
import 'package:daftar/presentation/screens/settings/security_screen.dart';
import 'package:daftar/presentation/screens/settings/settings_screen.dart';
import 'package:daftar/presentation/screens/sync/sync_report_screen.dart';
import 'package:daftar/presentation/shared/widgets/main_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);

List<RouteBase> buildAppRoutes() {
  return [
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.onboardingPath,
      name: RouteNames.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.inviteCeremonyPath,
      name: RouteNames.inviteCeremony,
      builder: (context, state) {
        final token = state.uri.queryParameters['token'] ?? '';
        final status = state.uri.queryParameters['status'] ?? 'expired';
        final claimedBy = state.uri.queryParameters['claimedBy'];
        return ExpiredInviteCeremonyScreen(
          token: token,
          status: status,
          claimedBy: claimedBy,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.inviteAcceptPath,
      name: RouteNames.inviteAccept,
      builder: (context, state) {
        return InviteAcceptHandoffScreen(
          token: state.uri.queryParameters['token'] ?? '',
          kind: state.uri.queryParameters['kind'],
          workspaceId: state.uri.queryParameters['workspaceId'],
          email: state.uri.queryParameters['email'],
          role: state.uri.queryParameters['role'],
        );
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(
          currentLocation: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: RouteNames.homePath,
          name: RouteNames.home,
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: RouteNames.settingsPath,
          name: RouteNames.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.importCsvPath,
          name: RouteNames.importCsv,
          builder: (context, state) {
            final ledgerId =
                state.uri.queryParameters[RouteNames.ledgerIdParam];
            return ImportCsvScreen(prefetchedLedgerId: ledgerId);
          },
        ),
        GoRoute(
          path: RouteNames.backupPath,
          name: RouteNames.backup,
          builder: (context, state) => const BackupScreen(),
        ),
        GoRoute(
          path: RouteNames.activationPath,
          name: RouteNames.activation,
          builder: (context, state) => const ActivationScreen(),
        ),
        GoRoute(
          path: RouteNames.securityPath,
          name: RouteNames.security,
          builder: (context, state) => const SecurityScreen(),
        ),
        GoRoute(
          path: RouteNames.merchantBrandingPath,
          name: RouteNames.merchantBranding,
          builder: (context, state) => const MerchantBrandingScreen(),
        ),
        if (kDebugMode)
          GoRoute(
            path: RouteNames.preflightSmokeTestPath,
            name: RouteNames.preflightSmokeTest,
            builder: (context, state) => const PreflightSmokeTestScreen(),
          ),
        GoRoute(
          path: RouteNames.syncReportPath,
          name: RouteNames.syncReport,
          builder: (context, state) => const SyncReportScreen(),
        ),
        GoRoute(
          path: RouteNames.memberManagementPath,
          name: RouteNames.memberManagement,
          builder: (context, state) => const MemberManagementScreen(),
        ),
        GoRoute(
          path: RouteNames.joinWorkspacePath,
          name: RouteNames.joinWorkspace,
          builder: (context, state) => const JoinWorkspaceScreen(),
        ),
        GoRoute(
          path: RouteNames.accountManagementPath,
          name: RouteNames.accountManagement,
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              // ignore: avoid_redundant_argument_values -- ties route to animationSnappyEnter.
              transitionDuration: AppDimensions.animationSnappyEnter,
              reverseTransitionDuration: AppDimensions.animationSnappyExit,
              child: const AccountManagementScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.curvePageLuxuryEnter,
                  reverseCurve: AppMotion.curvePageLuxuryExit,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
            );
          },
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.closingAgentPath,
      name: RouteNames.closingAgent,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          // ignore: avoid_redundant_argument_values -- ties route to animationSnappyEnter.
          transitionDuration: AppDimensions.animationSnappyEnter,
          reverseTransitionDuration: AppDimensions.animationSnappyExit,
          child: const ClosingAgentScreen(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curvePageLuxuryEnter,
              reverseCurve: AppMotion.curvePageLuxuryExit,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.archiveVaultPath,
      name: RouteNames.archiveVault,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          // ignore: avoid_redundant_argument_values -- ties route to animationSnappyEnter.
          transitionDuration: AppDimensions.animationSnappyEnter,
          reverseTransitionDuration: AppDimensions.animationSnappyExit,
          child: const ArchiveVaultScreen(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curvePageLuxuryEnter,
              reverseCurve: AppMotion.curvePageLuxuryExit,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.ledgerDetailPath,
      name: RouteNames.ledgerDetail,
      builder: (context, state) {
        final ledgerId =
            state.pathParameters[RouteNames.ledgerIdParam] ??
            (state.extra is String ? state.extra! as String : null) ??
            'demo-ledger-id';

        return LedgerDetailScreen(
          ledgerId: ledgerId,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: RouteNames.contactDetailPath,
      name: RouteNames.contactDetail,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final contact = extra is Contact ? extra : null;
        final contactId =
            state.pathParameters[RouteNames.contactIdParam] ??
            (extra is String ? extra : null) ??
            contact?.id ??
            'demo-contact-id';

        return CustomTransitionPage(
          key: state.pageKey,
          // ignore: avoid_redundant_argument_values -- ties route to animationSnappyEnter.
          transitionDuration: AppDimensions.animationSnappyEnter,
          reverseTransitionDuration: AppDimensions.animationSnappyExit,
          child: ContactDetailScreen(
            contactId: contactId,
            contact: contact,
          ),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: AppMotion.curvePageLuxuryEnter,
              reverseCurve: AppMotion.curvePageLuxuryExit,
            );
            return FadeTransition(opacity: fade, child: child);
          },
        );
      },
    ),
  ];
}
