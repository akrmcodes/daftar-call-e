import 'dart:async';

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_actions_panel.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_identity_passport.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_session_banner.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_trust_manifest.dart';
import 'package:daftar/presentation/screens/settings/backup/widgets/backup_ambient_mesh.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_scroll_screen_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Google account vault — identity passport, trust manifest, and actions.
class AccountManagementScreen extends ConsumerWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    final authAsync = ref.watch(authStateProvider);
    final accountAsync = ref.watch(googleAccountProvider);
    final isSignInLoading = ref.watch(signInControllerProvider).isLoading;

    final surfaceColor =
        isDark ? AppColors.surface0 : AppColors.surface0Light;
    final bottomClearance = MediaQuery.paddingOf(context).bottom + 48;

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
                  l10n.accountManagementTitle,
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
                  child: authAsync.when(
                    loading: () => _AccountBodySkeleton(isDark: isDark),
                    error: (_, _) => _AccountBody(
                      isDark: isDark,
                      session: AuthSessionState.unlinked,
                      profile: null,
                      isProfileLoading: false,
                      isSignInLoading: isSignInLoading,
                      bottomClearance: bottomClearance,
                      ghostEmail: null,
                      onSignIn: () => _signIn(context, ref),
                      onManageBackup: () => _openBackup(context),
                      onSwitchAccount: () => _switchAccount(context, ref),
                      onSignOut: () => _confirmSignOut(context, ref),
                    ),
                    data: (session) {
                      if (session == AuthSessionState.unlinked ||
                          session == AuthSessionState.migrationRelinkRequired) {
                        final ghostEmail = session ==
                                AuthSessionState.migrationRelinkRequired
                            ? ref
                                .watch(appSettingsProvider)
                                .asData
                                ?.value
                                .googleAccountEmail
                            : null;

                        return _AccountBody(
                          isDark: isDark,
                          session: session,
                          profile: null,
                          isProfileLoading: false,
                          isSignInLoading: isSignInLoading,
                          bottomClearance: bottomClearance,
                          ghostEmail: ghostEmail,
                          onSignIn: () => _signIn(context, ref),
                          onManageBackup: () => _openBackup(context),
                          onSwitchAccount: () => _switchAccount(context, ref),
                          onSignOut: () => _confirmSignOut(context, ref),
                        );
                      }

                      return accountAsync.when(
                        loading: () => _AccountBody(
                          isDark: isDark,
                          session: session,
                          profile: null,
                          isProfileLoading: true,
                          isSignInLoading: isSignInLoading,
                          bottomClearance: bottomClearance,
                          ghostEmail: null,
                          onSignIn: () => _signIn(context, ref),
                          onManageBackup: () => _openBackup(context),
                          onSwitchAccount: () => _switchAccount(context, ref),
                          onSignOut: () => _confirmSignOut(context, ref),
                        ),
                        error: (_, _) => _AccountBody(
                          isDark: isDark,
                          session: session,
                          profile: null,
                          isProfileLoading: false,
                          isSignInLoading: isSignInLoading,
                          bottomClearance: bottomClearance,
                          ghostEmail: null,
                          onSignIn: () => _signIn(context, ref),
                          onManageBackup: () => _openBackup(context),
                          onSwitchAccount: () => _switchAccount(context, ref),
                          onSignOut: () => _confirmSignOut(context, ref),
                        ),
                        data: (profile) => _AccountBody(
                          isDark: isDark,
                          session: session,
                          profile: profile,
                          isProfileLoading: false,
                          isSignInLoading: isSignInLoading,
                          bottomClearance: bottomClearance,
                          ghostEmail: null,
                          onSignIn: () => _signIn(context, ref),
                          onManageBackup: () => _openBackup(context),
                          onSwitchAccount: () => _switchAccount(context, ref),
                          onSignOut: () => _confirmSignOut(context, ref),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openBackup(BuildContext context) async {
    await HapticService.light();
    if (!context.mounted) return;
    unawaited(context.pushNamed(RouteNames.backup));
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.light();
    final result =
        await ref.read(signInControllerProvider.notifier).signInWithGoogle();
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorTranslator.signInFailureMessage(l10n, failure)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await HapticService.light();
    if (!context.mounted) return;

    final confirmed = await AppBottomSheet.show<bool>(
      context,
      title: l10n.accountManagementSignOutConfirmTitle,
      scrollable: false,
      maxHeightFactor: 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.accountManagementSignOutConfirmBody,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.inkSecondary
                  : AppColors.inkSecondaryLight,
            ),
          ),
          const Gap(AppDimensions.spacingXl),
          DaftarButton(
            label: l10n.backupRestoreCancel,
            variant: DaftarButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: l10n.accountManagementSignOutConfirmCta,
            variant: DaftarButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _signOut(context, ref);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.medium();
    if (!context.mounted) return;
    final result = await ref.read(signInControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorTranslator.message(l10n, failure)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  Future<void> _switchAccount(BuildContext context, WidgetRef ref) async {
    await HapticService.selection();
    if (!context.mounted) return;
    await _signOut(context, ref);
    if (!context.mounted) return;
    await _signIn(context, ref);
  }
}

class _AccountBody extends StatelessWidget {
  const _AccountBody({
    required this.isDark,
    required this.session,
    required this.profile,
    required this.isProfileLoading,
    required this.isSignInLoading,
    required this.bottomClearance,
    required this.ghostEmail,
    required this.onSignIn,
    required this.onManageBackup,
    required this.onSwitchAccount,
    required this.onSignOut,
  });

  final bool isDark;
  final AuthSessionState session;
  final GoogleAccountProfile? profile;
  final bool isProfileLoading;
  final bool isSignInLoading;
  final double bottomClearance;
  final String? ghostEmail;
  final Future<void> Function() onSignIn;
  final Future<void> Function() onManageBackup;
  final Future<void> Function() onSwitchAccount;
  final Future<void> Function() onSignOut;

  bool get _isDriveReady => session == AuthSessionState.linked;

  bool get _showLinkedIdentity =>
      session == AuthSessionState.linked ||
      session == AuthSessionState.needsReauth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session == AuthSessionState.migrationRelinkRequired) ...[
          AccountMigrationRelinkBanner(
            isDark: isDark,
            isLoading: isSignInLoading,
            ghostEmail: ghostEmail,
            onSignIn: onSignIn,
          ),
          const Gap(AppDimensions.spacingXl),
        ],
        if (session == AuthSessionState.needsReauth) ...[
          AccountNeedsReauthBanner(
            isDark: isDark,
            isLoading: isSignInLoading,
            onSignIn: onSignIn,
          ),
          const Gap(AppDimensions.spacingXl),
        ],
        AccountIdentityPassport(
          isDark: isDark,
          isSignedIn: _showLinkedIdentity,
          isDriveReady: _isDriveReady,
          profile: profile,
          isLoading: isProfileLoading,
        ),
        const Gap(AppDimensions.spacingXxl),
        const AccountTrustManifest(),
        const Gap(AppDimensions.spacingXxl),
        if (_isDriveReady)
          AccountSignedInActions(
            isDark: isDark,
            onManageBackup: onManageBackup,
            onSwitchAccount: onSwitchAccount,
            onSignOut: onSignOut,
          )
        else if (session == AuthSessionState.needsReauth)
          AccountNeedsReauthActions(
            isDark: isDark,
            isGlobalLoading: isSignInLoading,
            onRestoreAccess: onSignIn,
            onSignOut: onSignOut,
          )
        else
          AccountSignedOutActions(
            isDark: isDark,
            isGlobalLoading: isSignInLoading,
            onSignIn: onSignIn,
          ),
        SizedBox(height: bottomClearance),
      ],
    );
  }
}

class _AccountBodySkeleton extends StatelessWidget {
  const _AccountBodySkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _AccountBody(
      isDark: isDark,
      session: AuthSessionState.unlinked,
      profile: null,
      isProfileLoading: true,
      isSignInLoading: false,
      bottomClearance: 48,
      ghostEmail: null,
      onSignIn: () async {},
      onManageBackup: () async {},
      onSwitchAccount: () async {},
      onSignOut: () async {},
    );
  }
}
