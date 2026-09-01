import 'dart:async' show unawaited;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/providers/entitlement_providers.dart';
import 'package:daftar/presentation/screens/premium/widgets/tier_accent_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact Khazna-compliant plan chip for the home app bar.
///
/// Monochrome surface + lapis border/glow per `docs/design_system.md` §16.2.
/// Tap opens the activation hub.
class PremiumTierBadge extends ConsumerStatefulWidget {
  const PremiumTierBadge({super.key});

  @override
  ConsumerState<PremiumTierBadge> createState() => _PremiumTierBadgeState();
}

class _PremiumTierBadgeState extends ConsumerState<PremiumTierBadge> {
  bool _pressed = false;

  void _onTap(BuildContext context) {
    unawaited(HapticService.buttonPress());
    unawaited(context.pushNamed(RouteNames.activation));
  }

  @override
  Widget build(BuildContext context) {
    final entitlementAsync = ref.watch(entitlementProvider);
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;

    return entitlementAsync.when(
      data: (entitlement) {
        final tier = entitlement.tier;
        final label = switch (tier) {
          AppTier.proPlus => l10n.premiumBadgeProPlus,
          AppTier.pro => l10n.premiumBadgePro,
          AppTier.free => l10n.planTierFree,
        };

        final fillColor =
            isDark ? AppColors.surface3 : AppColors.surface2Light;
        final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
        final mutedInk =
            isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

        final borderColor = switch (tier) {
          AppTier.free => isDark
              ? AppColors.borderSubtle
              : AppColors.borderSubtleLight,
          AppTier.pro => AppColors.lapis400.withValues(alpha: 0.55),
          AppTier.proPlus => AppColors.lapis400,
        };

        final glow = switch (tier) {
          AppTier.free => null,
          AppTier.pro => AppGlows.haloXs,
          AppTier.proPlus => AppGlows.haloSm,
        };

        final labelStyle = switch (tier) {
          AppTier.free => AppTextStyles.labelMedium.copyWith(
              color: mutedInk,
              fontWeight: FontWeight.w600,
            ),
          _ => AppTextStyles.titleSmall.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
        };

        return Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: () => _onTap(context),
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1,
              duration: AppDimensions.animationFast,
              curve: Curves.easeOutCubic,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppDimensions.minTapTarget,
                  minHeight: AppDimensions.minTapTarget,
                ),
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCircular,
                      ),
                      border: Border.all(color: borderColor, width: 0.5),
                      boxShadow: glow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusCircular,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (isDark)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 1,
                              child: ColoredBox(
                                color: AppColors.innerTopHighlight,
                              ),
                            ),
                          if (tier == AppTier.proPlus)
                            PositionedDirectional(
                              start: 0,
                              top: AppDimensions.spacingXs,
                              bottom: AppDimensions.spacingXs,
                              child: Container(
                                width: 1.5,
                                decoration: BoxDecoration(
                                  color: AppColors.lapis400,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusCircular,
                                  ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppDimensions.spacingXs,
                              AppDimensions.spacingXxs,
                              AppDimensions.spacingSm,
                              AppDimensions.spacingXxs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TierMedallion(tier: tier, isDark: isDark),
                                const SizedBox(width: AppDimensions.spacingXs),
                                Text(
                                  label,
                                  style: labelStyle,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
            );
      },
      loading: () => _BadgeSkeleton(isDark: isDark),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Tier icon — bare glyph, no medallion ring.
class _TierMedallion extends StatelessWidget {
  const _TierMedallion({
    required this.tier,
    required this.isDark,
  });

  final AppTier tier;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final mutedInk = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final iconColor = tier == AppTier.free ? mutedInk : ink;

    return Icon(
      TierAccentTokens.tierIcon(tier),
      size: AppDimensions.iconSmall,
      color: iconColor,
    );
  }
}

/// Placeholder matching the badge pill geometry while entitlement loads.
class _BadgeSkeleton extends StatelessWidget {
  const _BadgeSkeleton({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppDimensions.minTapTarget,
      height: AppDimensions.minTapTarget,
      child: Center(
        child: Container(
          width: 68,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface3 : AppColors.surface2Light,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(
              color: isDark
                  ? AppColors.borderSubtle
                  : AppColors.borderSubtleLight,
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
