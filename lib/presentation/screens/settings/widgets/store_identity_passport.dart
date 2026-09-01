import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/merchant_profile.dart';
import 'package:daftar/presentation/screens/settings/widgets/hero_bento_card.dart';
import 'package:daftar/presentation/screens/settings/widgets/pro_micro_badge.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_identity_completion_rail.dart';
import 'package:daftar/presentation/screens/settings/widgets/store_logo_seal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Merchant passport — floating logo seal over a Khazna hero card.
class StoreIdentityPassport extends StatelessWidget {
  const StoreIdentityPassport({
    required this.storeName,
    required this.phoneDisplay,
    required this.isDark,
    required this.hasLogo,
    required this.logoPath,
    required this.profile,
    required this.loadLogoBytes,
    required this.hasName,
    required this.hasPhone,
    super.key,
    this.compact = false,
    this.onTap,
    this.animate = true,
  });

  final String storeName;
  final String phoneDisplay;
  final bool isDark;
  final bool hasLogo;
  final String? logoPath;
  final MerchantProfile? profile;
  final Future<Uint8List?> Function(String path) loadLogoBytes;
  final bool hasName;
  final bool hasPhone;
  final bool compact;
  final VoidCallback? onTap;
  final bool animate;

  static const _logoDiameter = 104.0;
  static const _logoOverlap = 54.0;
  static const _cardBodyTopInset = 70.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final displayName = storeName.trim().isEmpty
        ? l10n.merchantBrandingStoreName
        : storeName.trim();

    final logoDiameter = compact ? 64.0 : _logoDiameter;
    final logoOverlap = compact ? 34.0 : _logoOverlap;
    final cardBodyTopInset = compact ? 44.0 : _cardBodyTopInset;

    Widget passport = SizedBox(
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.only(top: logoOverlap),
            child: _PassportCard(
              isDark: isDark,
              compact: compact,
              cardBodyTopInset: cardBodyTopInset,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ProMicroBadge(),
                        const Gap(AppDimensions.spacingSm),
                        Flexible(
                          child: Text(
                            l10n.merchantBrandingScreenTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: inkMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!compact) const Gap(AppDimensions.spacingLg),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? AppTextStyles.titleMedium
                            : AppTextStyles.displaySmall)
                        .copyWith(
                      color: storeName.trim().isEmpty
                          ? inkSecondary
                          : inkPrimary,
                      letterSpacing: compact ? 0 : -0.6,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(compact ? AppDimensions.spacingSm : AppDimensions.spacingXl),
                  if (!compact || phoneDisplay != '—')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call_outlined,
                          size: AppDimensions.iconSmall,
                          color: inkMuted,
                        ),
                        const Gap(AppDimensions.spacingSm),
                        Flexible(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              phoneDisplay,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: inkSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (!compact) ...[
                    const Gap(AppDimensions.spacingMd),
                    Text(
                      l10n.merchantBrandingScreenSubtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: inkMuted,
                      ),
                    ),
                    const Gap(AppDimensions.spacingXl),
                    StoreIdentityCompletionRail(
                      hasName: hasName,
                      hasPhone: hasPhone,
                      hasLogo: hasLogo,
                      compact: true,
                    ),
                  ],
                  if (onTap != null && !compact) ...[
                    const Gap(AppDimensions.spacingLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: inkMuted,
                        ),
                        const Gap(AppDimensions.spacingXxs),
                        Text(
                          l10n.merchantBrandingTapToEdit,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: StoreLogoSeal(
              diameter: logoDiameter,
              isDark: isDark,
              hasLogo: hasLogo,
              logoPath: logoPath,
              profile: profile,
              loadLogoBytes: loadLogoBytes,
              ringWidth: compact ? 3 : 4,
            ),
          ),
        ],
      ),
    );

    if (animate) {
      passport = passport
          .animate()
          .fadeIn(
            duration: AppDimensions.animationSlow,
            curve: Curves.easeOutCubic,
          )
          .slideY(
            begin: 0.06,
            end: 0,
            duration: AppDimensions.animationSlow,
            curve: Curves.easeOutCubic,
          );
    }

    return passport;
  }
}

class _PassportCard extends StatelessWidget {
  const _PassportCard({
    required this.isDark,
    required this.compact,
    required this.cardBodyTopInset,
    required this.child,
    this.onTap,
  });

  final bool isDark;
  final bool compact;
  final double cardBodyTopInset;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsetsDirectional.fromSTEB(
      compact ? AppDimensions.spacingLg : AppDimensions.spacingXxl,
      cardBodyTopInset,
      compact ? AppDimensions.spacingLg : AppDimensions.spacingXxl,
      compact ? AppDimensions.spacingLg : AppDimensions.spacingXxl,
    );

    Widget card = HeroBentoCard(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: () {
          unawaited(HapticService.light());
          onTap?.call();
        },
        child: card,
      );
    }

    return card;
  }
}

/// Perforated ledger edge — decorative top border for the passport zone.
class LedgerPerforationPainter extends CustomPainter {
  LedgerPerforationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const holeRadius = 2.0;
    const spacing = 10.0;
    var x = spacing;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height / 2), holeRadius, paint);
      x += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant LedgerPerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}
