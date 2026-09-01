import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/google_account_profile.dart';
import 'package:daftar/presentation/screens/settings/account_management/widgets/account_avatar_seal.dart';
import 'package:daftar/presentation/screens/settings/widgets/hero_bento_card.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Google identity passport — floating avatar seal over a Khazna hero card.
class AccountIdentityPassport extends StatelessWidget {
  const AccountIdentityPassport({
    required this.isDark,
    required this.isSignedIn,
    super.key,
    this.profile,
    this.isLoading = false,
    this.isDriveReady = false,
  });

  final bool isDark;
  final bool isSignedIn;
  final GoogleAccountProfile? profile;
  final bool isLoading;

  /// When true, shows the green "Connected" badge (Drive session warm).
  final bool isDriveReady;

  static const _avatarOverlap = 54.0;
  static const _cardBodyTopInset = 70.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final email = profile?.email ?? '';
    final displayName = profile?.displayName?.trim();
    final name = isSignedIn
        ? ((displayName != null && displayName.isNotEmpty)
            ? displayName
            : (email.isNotEmpty ? email : l10n.accountManagementTitle))
        : l10n.settingsGoogleAccountSignInPrompt;

    Widget passport = SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: _avatarOverlap),
            child: HeroBentoCard(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppDimensions.spacingXxl,
                _cardBodyTopInset,
                AppDimensions.spacingXxl,
                AppDimensions.spacingXxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDriveReady && !isLoading) ...[
                    Center(child: _ConnectedBadge(isDark: isDark)),
                    const Gap(AppDimensions.spacingMd),
                  ],
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.displaySmall.copyWith(
                      color: isSignedIn ? inkPrimary : inkSecondary,
                      letterSpacing: -0.4,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isSignedIn && email.isNotEmpty) ...[
                    const Gap(AppDimensions.spacingMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.alternate_email_rounded,
                          size: AppDimensions.iconSmall,
                          color: inkMuted,
                        ),
                        const Gap(AppDimensions.spacingSm),
                        Flexible(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              email,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: inkSecondary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isSignedIn) ...[
                    const Gap(AppDimensions.spacingMd),
                    Text(
                      l10n.accountManagementSubtitle,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: isLoading
                ? const AccountAvatarSealSkeleton()
                : AccountAvatarSeal(
                    isDark: isDark,
                    displayName: name,
                    photoUrl: profile?.photoUrl,
                    isPlaceholder: !isSignedIn,
                    showGlow: isSignedIn,
                  ),
          ),
        ],
      ),
    );

    if (isLoading) {
      passport = Skeletonizer(child: passport);
    } else {
      passport = passport
          .animate()
          .fadeIn(
            duration: AppDimensions.animationSlow,
            curve: Curves.easeOutCubic,
          )
          .slideY(
            begin: 0.05,
            end: 0,
            duration: AppDimensions.animationSlow,
            curve: Curves.easeOutCubic,
          );
    }

    return FadeSlideTransition(
      delay: const Duration(milliseconds: 60),
      duration: AppDimensions.animationSlow,
      child: passport,
    );
  }
}

class _ConnectedBadge extends StatelessWidget {
  const _ConnectedBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface5 : AppColors.surface3Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        border: Border.all(
          color: AppColors.payment.withValues(alpha: 0.35),
          width: AppDimensions.dividerThickness,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingXxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.payment,
                shape: BoxShape.circle,
              ),
            ),
            const Gap(AppDimensions.spacingSm),
            Text(
              l10n.accountManagementConnectedBadge,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.payment,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
