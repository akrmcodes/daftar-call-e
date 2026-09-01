import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/presentation/screens/settings/member_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `invite-worker` Edge Function silently downgrades an `editor` invite to
/// `viewer` once every editor seat is taken and returns the *effective* role.
/// Showing the link without that difference tells the owner they hired an
/// editor who cannot record a single transaction.
void main() {
  WorkerInviteResult invite({
    required WorkspaceRole role,
    required WorkspaceRole requestedRole,
    bool roleDowngraded = false,
  }) =>
      WorkerInviteResult(
        memberId: 'member-1',
        inviteUrl: 'https://daftar.app/i/abc123',
        role: role,
        expiresAt: DateTime.utc(2026, 8, 10),
        requestedRole: requestedRole,
        roleDowngraded: roleDowngraded,
      );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required WorkspaceRole requested,
    required WorkspaceRole granted,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showInviteResultSheet(
                  context,
                  invite(
                    role: granted,
                    requestedRole: requested,
                    roleDowngraded: granted != requested,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('warns when the server granted viewer instead of editor',
      (tester) async {
    await pumpSheet(
      tester,
      requested: WorkspaceRole.editor,
      granted: WorkspaceRole.viewer,
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.memberManagementInviteDowngradedTitle), findsOne);
    expect(find.text(l10n.memberManagementInviteDowngradedBody), findsOne);
    expect(
      find.text(
        l10n.memberManagementInviteRoleGranted(
          l10n.memberManagementRoleViewer,
        ),
      ),
      findsOne,
    );
  });

  testWidgets('stays quiet when the granted role matches the request',
      (tester) async {
    await pumpSheet(
      tester,
      requested: WorkspaceRole.editor,
      granted: WorkspaceRole.editor,
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.memberManagementInviteDowngradedTitle), findsNothing);
    expect(
      find.text(
        l10n.memberManagementInviteRoleGranted(
          l10n.memberManagementRoleEditor,
        ),
      ),
      findsOne,
    );
  });

  testWidgets('the downgrade warning is localized in Arabic', (tester) async {
    await pumpSheet(
      tester,
      requested: WorkspaceRole.editor,
      granted: WorkspaceRole.viewer,
      locale: const Locale('ar'),
    );

    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(ar.memberManagementInviteDowngradedTitle), findsOne);
    expect(
      ar.memberManagementInviteDowngradedTitle,
      isNot(en.memberManagementInviteDowngradedTitle),
      reason: 'Arabic copy must not fall through to the English string',
    );
  });
}
