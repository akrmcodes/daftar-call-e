import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/collaboration/accept_worker_invite_use_case.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/collaboration_invite_providers.dart';
import 'package:daftar/presentation/providers/deep_link_providers.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:daftar/presentation/providers/sync_auth_bridge_provider.dart';
import 'package:daftar/presentation/providers/sync_engine_providers.dart';
import 'package:daftar/presentation/providers/sync_providers.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Worker invite acceptance screen (Stage 8.6).
class InviteAcceptHandoffScreen extends ConsumerStatefulWidget {
  /// Creates the acceptance screen.
  const InviteAcceptHandoffScreen({
    required this.token,
    this.kind,
    this.workspaceId,
    this.email,
    this.role,
    super.key,
  });

  /// Deep-link token.
  final String token;

  /// Wire kind when share/referral placeholder.
  final String? kind;

  /// Workspace id when present.
  final String? workspaceId;

  /// Invited email for worker invites.
  final String? email;

  /// Assigned role wire value.
  final String? role;

  @override
  ConsumerState<InviteAcceptHandoffScreen> createState() =>
      _InviteAcceptHandoffScreenState();
}

class _InviteAcceptHandoffScreenState
    extends ConsumerState<InviteAcceptHandoffScreen> {
  bool _accepting = false;
  bool _succeeded = false;
  String? _error;
  WorkspaceRole? _joinedRole;

  bool get _isWorkerInvite =>
      widget.email != null && widget.email!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_succeeded) {
          unawaited(
            ref.read(handledDeepLinkStoreProvider).markHandled(widget.token),
          );
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surface1 : AppColors.surface0Light,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.surface2 : AppColors.surface1Light,
          title: Text(
            l10n.inviteAcceptTitle,
            style: AppTextStyles.headlineLarge.copyWith(color: ink),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2 : AppColors.surface1Light,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lapis400, width: 0.5),
                boxShadow: AppGlows.haloSm,
              ),
              child: _succeeded
                  ? _buildSuccess(context, l10n, ink, muted)
                  : _buildPreview(context, l10n, ink, muted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    AppLocalizations l10n,
    Color ink,
    Color muted,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = WorkspaceRole.fromString(widget.role);
    final roleLabel = _roleLabel(l10n, role);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.inviteAcceptPreviewTitle,
          style: AppTextStyles.headlineMedium.copyWith(color: ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          _isWorkerInvite
              ? l10n.inviteAcceptPreviewBody
              : l10n.inviteAcceptSuccessBody(
                  _roleLabel(l10n, WorkspaceRole.viewer) ?? '',
                ),
          style: AppTextStyles.bodyLarge.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        if (widget.email != null) ...[
          const SizedBox(height: 20),
          Text(
            l10n.inviteAcceptInvitedEmailLabel,
            style: AppTextStyles.labelMedium.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            widget.email!,
            style: AppTextStyles.bodyMedium.copyWith(color: ink),
            textAlign: TextAlign.center,
          ),
        ],
        if (roleLabel != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.inviteAcceptRoleLabel,
            style: AppTextStyles.labelMedium.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            roleLabel,
            style: AppTextStyles.bodyMedium.copyWith(color: ink),
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.debt : AppColors.debtLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (_isWorkerInvite) ...[
          const SizedBox(height: 24),
          DaftarButton(
            label: _accepting
                ? l10n.inviteAcceptInProgress
                : l10n.inviteAcceptCta,
            isLoading: _accepting,
            isExpanded: true,
            onPressed: _accepting ? null : _acceptInvite,
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    AppLocalizations l10n,
    Color ink,
    Color muted,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.inviteAcceptSuccessTitle,
          style: AppTextStyles.headlineMedium.copyWith(color: ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.inviteAcceptSuccessBody(
            _roleLabel(l10n, _joinedRole) ?? '',
          ),
          style: AppTextStyles.bodyLarge.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        DaftarButton(
          label: l10n.inviteAcceptContinueHome,
          isExpanded: true,
          onPressed: () => context.go(RouteNames.homePath),
        ),
      ],
    );
  }

  Future<void> _acceptInvite() async {
    final invitedEmail = widget.email?.trim();
    if (invitedEmail == null || invitedEmail.isEmpty) {
      return;
    }

    setState(() {
      _accepting = true;
      _error = null;
    });

    final result = await ref.read(acceptWorkerInviteUseCaseProvider).call(
          AcceptWorkerInviteParams(
            token: widget.token,
            invitedEmail: invitedEmail,
            role: WorkspaceRole.fromString(widget.role),
            workspaceId: widget.workspaceId,
          ),
        );

    if (!mounted) {
      return;
    }

    await result.fold<Future<void>>(
      (failure) async {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _accepting = false;
          _error = failure.code == 'invite_email_mismatch'
              ? l10n.inviteAcceptEmailMismatch(invitedEmail)
              : l10n.inviteAcceptErrorGeneric;
        });
      },
      (accepted) async {
        final l10n = AppLocalizations.of(context)!;
        final expectedWorkspaceId = widget.workspaceId?.trim();
        if (expectedWorkspaceId != null &&
            expectedWorkspaceId.isNotEmpty &&
            accepted.workspaceId != expectedWorkspaceId) {
          setState(() {
            _accepting = false;
            _error = l10n.inviteAcceptWorkspaceMismatch;
          });
          return;
        }

        final isWorkerRole = accepted.role == WorkspaceRole.editor ||
            accepted.role == WorkspaceRole.viewer;
        if (!isWorkerRole) {
          setState(() {
            _accepting = false;
            _error = l10n.inviteAcceptWorkspaceMismatch;
          });
          return;
        }

        await ref.read(handledDeepLinkStoreProvider).markHandled(widget.token);
        ref
          ..invalidate(syncAuthBridgeProvider)
          ..invalidate(isMultiDeviceSyncUnlockedUseCaseProvider)
          ..invalidate(isMultiDeviceSyncUnlockedProvider)
          ..invalidate(currentWorkspaceRoleProvider)
          ..invalidate(syncEngineControllerProvider);
        await ref.read(authStateProvider.notifier).refreshAfterAuthMutation();

        ref.invalidate(syncEngineControllerProvider);
        await ref.read(syncEngineControllerProvider.future);
        await ref.read(syncEngineControllerProvider.notifier).syncNow();

        if (!mounted) {
          return;
        }

        setState(() {
          _accepting = false;
          _succeeded = true;
          _joinedRole = accepted.role;
        });
      },
    );
  }

  String? _roleLabel(AppLocalizations l10n, WorkspaceRole? role) {
    return switch (role) {
      WorkspaceRole.editor => l10n.memberManagementRoleEditor,
      WorkspaceRole.viewer => l10n.memberManagementRoleViewer,
      WorkspaceRole.owner => l10n.memberManagementRoleOwner,
      null => null,
    };
  }
}
