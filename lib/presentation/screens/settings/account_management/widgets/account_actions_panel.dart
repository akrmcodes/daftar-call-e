import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_google_button.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_group.dart';
import 'package:daftar/presentation/screens/settings/widgets/settings_tile.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Signed-in account actions — backup shortcut, switch, and sign-out.
class AccountSignedInActions extends StatefulWidget {
  const AccountSignedInActions({
    required this.isDark,
    required this.onManageBackup,
    required this.onSwitchAccount,
    required this.onSignOut,
    super.key,
  });

  final bool isDark;
  final Future<void> Function() onManageBackup;
  final Future<void> Function() onSwitchAccount;
  final Future<void> Function() onSignOut;

  @override
  State<AccountSignedInActions> createState() => _AccountSignedInActionsState();
}

class _AccountSignedInActionsState extends State<AccountSignedInActions> {
  bool _isSwitchLoading = false;
  bool _isSignOutLoading = false;

  bool get _anyLoading => _isSwitchLoading || _isSignOutLoading;

  Future<void> _handleSwitch() async {
    if (_anyLoading) return;
    setState(() => _isSwitchLoading = true);
    try {
      await widget.onSwitchAccount();
    } finally {
      if (mounted) setState(() => _isSwitchLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_anyLoading) return;
    setState(() => _isSignOutLoading = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSignOutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 180),
      duration: AppDimensions.animationSlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsGroup(
            title: l10n.accountManagementActionsTitle,
            children: [
              SettingsTile(
                icon: Icons.backup_outlined,
                title: l10n.accountManagementManageBackup,
                subtitle: l10n.accountManagementManageBackupSubtitle,
                onTap: _anyLoading
                    ? null
                    : () {
                        unawaited(widget.onManageBackup());
                      },
              ),
            ],
          ),
          const Gap(AppDimensions.spacingXxl),
          AccountGoogleButton(
            label: l10n.accountManagementSwitchAccount,
            isDark: widget.isDark,
            isLoading: _isSwitchLoading,
            onPressed: _anyLoading ? null : _handleSwitch,
            icon: Icons.swap_horiz_rounded,
          ),
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: l10n.accountManagementSignOut,
            variant: DaftarButtonVariant.destructiveOutlined,
            isLoading: _isSignOutLoading,
            isExpanded: true,
            onPressed: _anyLoading ? null : _handleSignOut,
          ),
        ],
      ),
    );
  }
}

/// Needs-reauth actions — restore Drive access while keeping linked identity visible.
class AccountNeedsReauthActions extends StatefulWidget {
  const AccountNeedsReauthActions({
    required this.isDark,
    required this.onRestoreAccess,
    required this.onSignOut,
    super.key,
    this.isGlobalLoading = false,
  });

  final bool isDark;
  final Future<void> Function() onRestoreAccess;
  final Future<void> Function() onSignOut;
  final bool isGlobalLoading;

  @override
  State<AccountNeedsReauthActions> createState() =>
      _AccountNeedsReauthActionsState();
}

class _AccountNeedsReauthActionsState extends State<AccountNeedsReauthActions> {
  bool _isRestoreLoading = false;
  bool _isSignOutLoading = false;

  bool get _anyLoading =>
      _isRestoreLoading || _isSignOutLoading || widget.isGlobalLoading;

  Future<void> _handleRestore() async {
    if (_anyLoading) return;
    setState(() => _isRestoreLoading = true);
    try {
      await widget.onRestoreAccess();
    } finally {
      if (mounted) setState(() => _isRestoreLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    if (_anyLoading) return;
    setState(() => _isSignOutLoading = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSignOutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 180),
      duration: AppDimensions.animationSlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountGoogleButton(
            label: l10n.accountManagementRestoreAccess,
            isDark: widget.isDark,
            isLoading: _isRestoreLoading || widget.isGlobalLoading,
            variant: AccountGoogleButtonVariant.primary,
            onPressed: _anyLoading ? null : _handleRestore,
          ),
          const Gap(AppDimensions.spacingMd),
          DaftarButton(
            label: l10n.accountManagementSignOut,
            variant: DaftarButtonVariant.destructiveOutlined,
            isLoading: _isSignOutLoading,
            isExpanded: true,
            onPressed: _anyLoading ? null : _handleSignOut,
          ),
        ],
      ),
    );
  }
}

/// Signed-out sign-in CTA — primary Google button with isolated loading.
class AccountSignedOutActions extends StatefulWidget {
  const AccountSignedOutActions({
    required this.isDark,
    required this.onSignIn,
    super.key,
    this.signInLabel,
    this.isGlobalLoading = false,
  });

  final bool isDark;
  final Future<void> Function() onSignIn;
  final String? signInLabel;
  final bool isGlobalLoading;

  @override
  State<AccountSignedOutActions> createState() => _AccountSignedOutActionsState();
}

class _AccountSignedOutActionsState extends State<AccountSignedOutActions> {
  bool _isLoading = false;

  bool get _anyLoading => _isLoading || widget.isGlobalLoading;

  Future<void> _handleSignIn() async {
    if (_anyLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onSignIn();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 180),
      duration: AppDimensions.animationSlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccountGoogleButton(
            label: widget.signInLabel ?? l10n.backupDriveSignInWithGoogle,
            isDark: widget.isDark,
            isLoading: _anyLoading,
            variant: AccountGoogleButtonVariant.primary,
            onPressed: _anyLoading ? null : _handleSignIn,
          ),
          const Gap(AppDimensions.spacingMd),
          Text(
            l10n.accountManagementStatusDisconnectedSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: widget.isDark
                  ? AppColors.inkMuted
                  : AppColors.inkMutedLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
