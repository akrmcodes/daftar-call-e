import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/auth_session_state.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_google_button.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Info banner for Auth V2 [AuthSessionState.migrationRelinkRequired].
class AccountMigrationRelinkBanner extends StatelessWidget {
  const AccountMigrationRelinkBanner({
    required this.isDark,
    required this.isLoading,
    required this.onSignIn,
    super.key,
    this.ghostEmail,
  });

  final bool isDark;
  final bool isLoading;
  final Future<void> Function() onSignIn;
  final String? ghostEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _AccountSessionBanner(
      isDark: isDark,
      title: l10n.accountManagementMigrationRelinkTitle,
      body: l10n.accountManagementMigrationRelinkBody,
      secondaryHint: _ghostEmailHint(ghostEmail),
      ctaLabel: l10n.backupDriveSignInWithGoogle,
      isLoading: isLoading,
      onSignIn: onSignIn,
    );
  }
}

/// Info banner for Auth V2 [AuthSessionState.needsReauth].
class AccountNeedsReauthBanner extends StatelessWidget {
  const AccountNeedsReauthBanner({
    required this.isDark,
    required this.isLoading,
    required this.onSignIn,
    super.key,
  });

  final bool isDark;
  final bool isLoading;
  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _AccountSessionBanner(
      isDark: isDark,
      title: l10n.accountManagementNeedsReauthTitle,
      body: l10n.accountManagementNeedsReauthBody,
      ctaLabel: l10n.backupDriveSignInAgain,
      isLoading: isLoading,
      onSignIn: onSignIn,
    );
  }
}

String? _ghostEmailHint(String? email) {
  final trimmed = email?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _AccountSessionBanner extends StatefulWidget {
  const _AccountSessionBanner({
    required this.isDark,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.isLoading,
    required this.onSignIn,
    this.secondaryHint,
  });

  final bool isDark;
  final String title;
  final String body;
  final String? secondaryHint;
  final String ctaLabel;
  final bool isLoading;
  final Future<void> Function() onSignIn;

  @override
  State<_AccountSessionBanner> createState() => _AccountSessionBannerState();
}

class _AccountSessionBannerState extends State<_AccountSessionBanner> {
  bool _isLocalLoading = false;

  bool get _anyLoading => widget.isLoading || _isLocalLoading;

  Future<void> _handleSignIn() async {
    if (_anyLoading) return;
    setState(() => _isLocalLoading = true);
    try {
      await widget.onSignIn();
    } finally {
      if (mounted) setState(() => _isLocalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.lapis800 : AppColors.lapis50;
    final ink = widget.isDark ? AppColors.onInfo : AppColors.onInfoLight;
    final border = AppColors.lapis400.withValues(alpha: 0.35);

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 30),
      duration: AppDimensions.animationSlow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: AppTextStyles.titleSmall.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppDimensions.spacingSm),
              Text(
                widget.body,
                style: AppTextStyles.bodySmall.copyWith(
                  color: ink,
                  height: 1.45,
                ),
              ),
              if (widget.secondaryHint != null) ...[
                const Gap(AppDimensions.spacingSm),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    widget.secondaryHint!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: ink.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const Gap(AppDimensions.spacingLg),
              AccountGoogleButton(
                label: widget.ctaLabel,
                isDark: widget.isDark,
                isLoading: _anyLoading,
                variant: AccountGoogleButtonVariant.primary,
                onPressed: _anyLoading ? null : _handleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
