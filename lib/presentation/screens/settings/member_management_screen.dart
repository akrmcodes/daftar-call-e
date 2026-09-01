import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/invite_renewal_request.dart';
import 'package:daftar/domain/entities/worker_invite_result.dart';
import 'package:daftar/domain/entities/workspace_member.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/enums/workspace_permission.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/providers/member_management_controller.dart';
import 'package:daftar/presentation/providers/permissions_providers.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_ambient_mesh.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:daftar/presentation/shared/widgets/daftar_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Owner-only team management — list members, invite workers, revoke invites.
class MemberManagementScreen extends ConsumerWidget {
  const MemberManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _listenMemberManagementErrors(context, ref);

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final surfaceColor =
        isDark ? AppColors.surface0 : AppColors.surface0Light;

    final canCollaborate = ref.watch(
      canUseFeatureProvider(FeatureFlag.multiDeviceSync),
    );
    final canManageTeam = ref.watch(
      canPerformProvider(WorkspacePermission.inviteWorkers),
    );

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const BackupAmbientMesh(),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              DaftarScrollScreenTitleSliver(
                title: Text(
                  l10n.memberManagementTitle,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: inkPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.pagePaddingH,
                  ),
                  child: canCollaborate.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.spacingXl),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => _UpgradeBanner(l10n: l10n, isDark: isDark),
                    data: (entitled) {
                      if (!entitled) {
                        return _UpgradeBanner(l10n: l10n, isDark: isDark);
                      }
                      return canManageTeam.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppDimensions.spacingXl),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (_, _) => _PermissionDenied(
                          l10n: l10n,
                          inkSecondary: inkSecondary,
                        ),
                        data: (allowed) {
                          if (!allowed) {
                            return _PermissionDenied(
                              l10n: l10n,
                              inkSecondary: inkSecondary,
                            );
                          }
                          return _TeamBody(
                            l10n: l10n,
                            isDark: isDark,
                            inkPrimary: inkPrimary,
                            inkSecondary: inkSecondary,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SliverGap(AppDimensions.spacing3xl),
            ],
          ),
        ],
      ),
      floatingActionButton: canCollaborate.maybeWhen(
        data: (entitled) {
          if (!entitled) {
            return null;
          }
          return canManageTeam.maybeWhen(
            data: (allowed) => allowed
                ? FloatingActionButton.extended(
                    onPressed: () => showMemberInviteSheet(context, ref),
                    backgroundColor:
                        isDark ? AppColors.surface3 : AppColors.surface2Light,
                    foregroundColor: inkPrimary,
                    elevation: 0,
                    label: Text(l10n.memberManagementInviteCta),
                    icon: const Icon(Icons.person_add_outlined),
                  )
                : null,
            orElse: () => null,
          );
        },
        orElse: () => null,
      ),
    );
  }
}

void _listenMemberManagementErrors(BuildContext context, WidgetRef ref) {
  ref.listen(memberManagementControllerProvider, (previous, next) {
    if (!next.hasError || next.error == null) {
      return;
    }
    if (identical(previous?.error, next.error)) {
      return;
    }
    final error = next.error!;
    unawaited(
      AppBottomSheet.showError(context, error: error).whenComplete(() {
        if (context.mounted) {
          ref.read(memberManagementControllerProvider.notifier).clearError();
        }
      }),
    );
  });
}

Future<void> showMemberInviteSheet(BuildContext context, WidgetRef ref) async {
  final parentContext = context;
  final l10n = AppLocalizations.of(parentContext)!;

  ref.read(memberManagementControllerProvider.notifier).clearError();

  final invite = await AppBottomSheet.show<WorkerInviteResult>(
    parentContext,
    title: l10n.memberManagementInviteSheetTitle,
    child: _MemberInviteSheetContent(
      ref: ref,
      parentContext: parentContext,
    ),
  );

  if (invite != null && parentContext.mounted) {
    await showInviteResultSheet(parentContext, invite);
  }
}

class _MemberInviteSheetContent extends ConsumerStatefulWidget {
  const _MemberInviteSheetContent({
    required this.ref,
    required this.parentContext,
  });

  final WidgetRef ref;
  final BuildContext parentContext;

  @override
  ConsumerState<_MemberInviteSheetContent> createState() =>
      _MemberInviteSheetContentState();
}

class _MemberInviteSheetContentState
    extends ConsumerState<_MemberInviteSheetContent> {
  late final TextEditingController _emailController;
  WorkspaceRole _selectedRole = WorkspaceRole.editor;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DaftarTextField(
          controller: _emailController,
          label: l10n.memberManagementEmailLabel,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.memberManagementRoleLabel,
          style: AppTextStyles.labelMedium.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.inkSecondary
                : AppColors.inkSecondaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        SegmentedButton<WorkspaceRole>(
          segments: [
            ButtonSegment(
              value: WorkspaceRole.editor,
              label: Text(l10n.memberManagementRoleEditor),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            ButtonSegment(
              value: WorkspaceRole.viewer,
              label: Text(l10n.memberManagementRoleViewer),
              icon: const Icon(Icons.visibility_outlined, size: 18),
            ),
          ],
          selected: {_selectedRole},
          onSelectionChanged: (selection) {
            setState(() => _selectedRole = selection.first);
          },
        ),
        const Gap(AppDimensions.spacingXl),
        DaftarButton(
          label: l10n.memberManagementSendInvite,
          isLoading: _isSubmitting,
          isExpanded: true,
          onPressed: _isSubmitting ? null : _sendInvite,
        ),
      ],
    );
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      return;
    }
    setState(() => _isSubmitting = true);
    final invite = await widget.ref
        .read(memberManagementControllerProvider.notifier)
        .inviteWorker(
          email: email,
          role: _selectedRole,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isSubmitting = false);
    if (invite == null) {
      return;
    }
    Navigator.of(context).pop(invite);
  }
}

/// Presents copy/share actions for a minted worker invite URL.
///
/// The workspace allows at most two concurrent editors including the owner,
/// so an `editor` invite past that seat is minted as a viewer. The server
/// reports that with [WorkerInviteResult.roleDowngraded]; showing the link
/// without it would tell the owner they hired an editor who in fact cannot
/// record a single transaction.
Future<void> showInviteResultSheet(
  BuildContext context,
  WorkerInviteResult invite,
) async {
  final l10n = AppLocalizations.of(context)!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final wasDowngraded = invite.roleDowngraded;

  await AppBottomSheet.show<void>(
    context,
    title: l10n.memberManagementInviteSuccessTitle,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (wasDowngraded) ...[
          _RoleDowngradeNotice(l10n: l10n, isDark: isDark),
          const Gap(AppDimensions.spacingLg),
        ],
        Text(
          l10n.memberManagementInviteRoleGranted(_roleLabel(l10n, invite.role)),
          style: AppTextStyles.labelMedium.copyWith(
            color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        SelectableText(
          invite.inviteUrl,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isDark
                ? AppColors.inkSecondary
                : AppColors.inkSecondaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        DaftarButton(
          label: l10n.memberManagementCopyLink,
          icon: Icons.copy_outlined,
          isExpanded: true,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: invite.inviteUrl));
            unawaited(HapticService.light());
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.memberManagementLinkCopied)),
            );
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.memberManagementShareLink,
          variant: DaftarButtonVariant.secondary,
          icon: Icons.share_outlined,
          isExpanded: true,
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: invite.inviteUrl),
          ),
        ),
      ],
    ),
  );
}

String _roleLabel(AppLocalizations l10n, WorkspaceRole role) {
  return switch (role) {
    WorkspaceRole.owner => l10n.memberManagementRoleOwner,
    WorkspaceRole.editor => l10n.memberManagementRoleEditor,
    WorkspaceRole.viewer => l10n.memberManagementRoleViewer,
  };
}

/// Warns the owner that the server granted less access than they asked for.
class _RoleDowngradeNotice extends StatelessWidget {
  const _RoleDowngradeNotice({required this.l10n, required this.isDark});

  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.warning : AppColors.warningLight;

    return Container(
      padding: const EdgeInsetsDirectional.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warningContainer
            : AppColors.warningContainerLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: accent, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: AppDimensions.iconSmall,
            color: accent,
          ),
          const Gap(AppDimensions.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.memberManagementInviteDowngradedTitle,
                  style: AppTextStyles.labelMedium.copyWith(color: accent),
                ),
                const Gap(AppDimensions.spacingXs),
                Text(
                  l10n.memberManagementInviteDowngradedBody,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.inkSecondary
                        : AppColors.inkSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({
    required this.l10n,
    required this.isDark,
  });

  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return DaftarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.memberManagementUpgradeTitle,
            style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
          ),
          const Gap(AppDimensions.spacingSm),
          Text(
            l10n.memberManagementUpgradeSubtitle,
            style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
          ),
          const Gap(AppDimensions.spacingLg),
          DaftarButton(
            label: l10n.memberManagementUpgradeCta,
            isExpanded: true,
            onPressed: () => context.pushNamed(RouteNames.activation),
          ),
        ],
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({
    required this.l10n,
    required this.inkSecondary,
  });

  final AppLocalizations l10n;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return DaftarCard(
      child: Text(
        l10n.memberManagementPermissionDenied,
        style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
      ),
    );
  }
}

class _TeamBody extends ConsumerWidget {
  const _TeamBody({
    required this.l10n,
    required this.isDark,
    required this.inkPrimary,
    required this.inkSecondary,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final Color inkPrimary;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(workspaceMembersProvider);
    final controllerState = ref.watch(memberManagementControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.memberManagementSubtitle,
          style: AppTextStyles.bodyMedium.copyWith(color: inkSecondary),
        ),
        const Gap(AppDimensions.spacingMd),
        Text(
          l10n.memberManagementSeatsHint,
          style: AppTextStyles.labelSmall.copyWith(color: inkSecondary),
        ),
        const Gap(AppDimensions.spacingLg),
        DaftarButton(
          label: l10n.memberManagementInviteCta,
          icon: Icons.person_add_outlined,
          isExpanded: true,
          onPressed: () => showMemberInviteSheet(context, ref),
        ),
        const Gap(AppDimensions.spacingXl),
        if (controllerState.isLoading)
          const Padding(
            padding: EdgeInsetsDirectional.only(bottom: AppDimensions.spacingMd),
            child: LinearProgressIndicator(),
          ),
        membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DaftarCard(
            child: Text(
              ErrorTranslator.message(l10n, error),
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.debt : AppColors.debtLight,
              ),
            ),
          ),
          data: (members) => _MembersList(
            l10n: l10n,
            isDark: isDark,
            inkPrimary: inkPrimary,
            inkSecondary: inkSecondary,
            members: members,
            onResendPendingInvite: (member) =>
                _resendPendingInvite(context, ref, member),
          ),
        ),
        ref.watch(inviteRenewalRequestsProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (renewals) {
            if (renewals.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(AppDimensions.spacingXl),
                _RenewalRequestsSection(
                  l10n: l10n,
                  isDark: isDark,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  renewals: renewals,
                  onResend: (renewal) =>
                      _resendRenewalInvite(context, ref, renewal),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _resendPendingInvite(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMember member,
  ) async {
    final email = member.invitedEmail?.trim();
    if (email == null || email.isEmpty) {
      return;
    }
    final invite = await ref
        .read(memberManagementControllerProvider.notifier)
        .inviteWorker(
          email: email,
          role: member.role,
        );
    if (!context.mounted || invite == null) {
      return;
    }
    await showInviteResultSheet(context, invite);
  }

  Future<void> _resendRenewalInvite(
    BuildContext context,
    WidgetRef ref,
    InviteRenewalRequest renewal,
  ) async {
    final members = ref.read(workspaceMembersProvider).asData?.value ?? const [];
    final pending = members.where(
      (member) =>
          member.isPending &&
          member.invitedEmail?.trim().toLowerCase() ==
              renewal.invitedEmail.trim().toLowerCase(),
    );
    final role = pending.isNotEmpty
        ? pending.first.role
        : WorkspaceRole.editor;

    final invite = await ref
        .read(memberManagementControllerProvider.notifier)
        .inviteWorker(
          email: renewal.invitedEmail,
          role: role,
        );
    if (!context.mounted || invite == null) {
      return;
    }

    await ref
        .read(memberManagementControllerProvider.notifier)
        .fulfillRenewalRequest(renewal.id);

    if (!context.mounted) {
      return;
    }
    await showInviteResultSheet(context, invite);
  }
}

class _RenewalRequestsSection extends StatelessWidget {
  const _RenewalRequestsSection({
    required this.l10n,
    required this.isDark,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.renewals,
    required this.onResend,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final Color inkPrimary;
  final Color inkSecondary;
  final List<InviteRenewalRequest> renewals;
  final Future<void> Function(InviteRenewalRequest renewal) onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.memberManagementRenewalSection,
          inkPrimary: inkPrimary,
        ),
        const Gap(AppDimensions.spacingSm),
        ...renewals.map(
          (renewal) => Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppDimensions.spacingSm,
            ),
            child: DaftarCard(
              variant: DaftarCardVariant.compact,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          renewal.invitedEmail.isNotEmpty
                              ? renewal.invitedEmail
                              : '${renewal.originalToken.length >= 8 ? renewal.originalToken.substring(0, 8) : renewal.originalToken}…',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: inkPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(AppDimensions.spacingXs),
                        Text(
                          l10n.memberManagementRenewalRequestedAt(
                            DateFormat.yMMMd(AppConstants.numeralLocale)
                                .format(renewal.createdAt.toLocal()),
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onResend(renewal),
                    child: Text(l10n.memberManagementRenewalResend),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MembersList extends ConsumerWidget {
  const _MembersList({
    required this.l10n,
    required this.isDark,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.members,
    required this.onResendPendingInvite,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final Color inkPrimary;
  final Color inkSecondary;
  final List<WorkspaceMember> members;
  final Future<void> Function(WorkspaceMember member) onResendPendingInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = members.where((m) => m.isActive).toList(growable: false);
    final pending = members.where((m) => m.isPending).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: l10n.memberManagementActiveSection,
          inkPrimary: inkPrimary,
        ),
        const Gap(AppDimensions.spacingSm),
        if (active.isEmpty)
          _EmptyHint(l10n: l10n, inkSecondary: inkSecondary)
        else
          ...active.map(
            (member) => _MemberTile(
              l10n: l10n,
              isDark: isDark,
              inkPrimary: inkPrimary,
              inkSecondary: inkSecondary,
              member: member,
              onRemove: member.isOwner
                  ? null
                  : () => _confirmRemove(context, ref, member),
            ),
          ),
        const Gap(AppDimensions.spacingXl),
        _SectionHeader(
          title: l10n.memberManagementPendingSection,
          inkPrimary: inkPrimary,
        ),
        const Gap(AppDimensions.spacingSm),
        if (pending.isEmpty)
          _EmptyHint(l10n: l10n, inkSecondary: inkSecondary)
        else
          ...pending.map(
            (member) => _MemberTile(
              l10n: l10n,
              isDark: isDark,
              inkPrimary: inkPrimary,
              inkSecondary: inkSecondary,
              member: member,
              onRevoke: () => _confirmRevoke(context, ref, member),
              onResendLink: () => onResendPendingInvite(member),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmRevoke(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memberManagementRevokeConfirmTitle),
        content: Text(l10n.memberManagementRevokeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backupRestoreCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.memberManagementRevokeInvite),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    unawaited(HapticService.light());
    await ref
        .read(memberManagementControllerProvider.notifier)
        .revokeInvite(member.id);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.memberManagementRemoveConfirmTitle),
        content: Text(l10n.memberManagementRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backupRestoreCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.memberManagementRemoveMember),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    unawaited(HapticService.light());
    await ref.read(memberManagementControllerProvider.notifier).removeMember(
          memberId: member.id,
          seatIndex: member.seatIndex,
        );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.inkPrimary,
  });

  final String title;
  final Color inkPrimary;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.titleSmall.copyWith(
        color: inkPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.l10n,
    required this.inkSecondary,
  });

  final AppLocalizations l10n;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingMd,
      ),
      child: Text(
        l10n.memberManagementEmptySection,
        style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.l10n,
    required this.isDark,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.member,
    this.onRevoke,
    this.onRemove,
    this.onResendLink,
  });

  final AppLocalizations l10n;
  final bool isDark;
  final Color inkPrimary;
  final Color inkSecondary;
  final WorkspaceMember member;
  final VoidCallback? onRevoke;
  final VoidCallback? onRemove;
  final VoidCallback? onResendLink;

  @override
  Widget build(BuildContext context) {
    final email = member.invitedEmail ?? '—';
    final roleLabel = _roleLabel(l10n, member.role);
    final statusLabel = member.isPending
        ? l10n.memberManagementStatusPending
        : l10n.memberManagementStatusActive;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingSm,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: inkPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppDimensions.spacingXs),
                  Text(
                    '$roleLabel · $statusLabel',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onResendLink != null)
              TextButton(
                onPressed: onResendLink,
                child: Text(l10n.memberManagementCopyLink),
              ),
            if (onRevoke != null)
              TextButton(
                onPressed: onRevoke,
                child: Text(l10n.memberManagementRevokeInvite),
              ),
            if (onRemove != null)
              TextButton(
                onPressed: onRemove,
                child: Text(
                  l10n.memberManagementRemoveMember,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isDark ? AppColors.debt : AppColors.debtLight,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
