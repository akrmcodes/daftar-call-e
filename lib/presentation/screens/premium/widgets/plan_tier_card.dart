import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Rectilinear Khazna plan card — price, highlights, CTA.
///
/// Selection uses surface + border only. Lapis glow lives exclusively on the
/// emphasized primary CTA (§16 / one-glow rule).
class PlanTierCard extends StatelessWidget {
  const PlanTierCard({
    required this.tier,
    required this.isSelected,
    required this.isCurrentPlan,
    required this.isRecommended,
    required this.emphasizeCta,
    required this.onSelect,
    required this.onCtaPressed,
    super.key,
  });

  final AppTier tier;
  final bool isSelected;
  final bool isCurrentPlan;
  final bool isRecommended;

  /// When true, the CTA wears primary lapis glow (mutually exclusive with
  /// activation-field focus elsewhere on the screen).
  final bool emphasizeCta;
  final VoidCallback onSelect;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final content = _contentFor(l10n, tier);

    final fill = isSelected
        ? (isDark ? AppColors.surface4 : AppColors.surface2Light)
        : (isDark ? AppColors.surface2 : AppColors.surface1Light);

    final borderColor = _borderColor(
      tier: tier,
      isSelected: isSelected,
      isDark: isDark,
    );

    final baseShadow = isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat;

    final ctaVariant = emphasizeCta && !isCurrentPlan && tier != AppTier.free
        ? DaftarButtonVariant.primary
        : DaftarButtonVariant.secondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: content.name,
      child: GestureDetector(
        onTap: () {
          unawaited(HapticService.light());
          onSelect();
        },
        child: AnimatedContainer(
          duration: AppDimensions.animationMedium,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: borderColor,
              width: AppDimensions.dividerThickness,
            ),
            boxShadow: baseShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Stack(
              children: [
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: Container(
                    height: AppDimensions.dividerThickness,
                    color: isDark
                        ? AppColors.innerTopHighlight
                        : Colors.transparent,
                  ),
                ),
                if (tier == AppTier.proPlus && isSelected)
                  PositionedDirectional(
                    start: 0,
                    top: 12,
                    bottom: 12,
                    child: Container(
                      width: 0.5,
                      color: AppColors.lapis400,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              content.name,
                              style: AppTextStyles.titleLarge.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecommended) ...[
                            const Gap(AppDimensions.spacingSm),
                            _BadgeChip(
                              label: l10n.tierBadgeRecommended,
                              emphasized: true,
                            ),
                          ],
                          if (content.badge != null) ...[
                            const Gap(AppDimensions.spacingSm),
                            _BadgeChip(label: content.badge!),
                          ],
                        ],
                      ),
                      const Gap(AppDimensions.spacingXs),
                      Text(
                        content.tagline,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(AppDimensions.spacingLg),
                      _PriceRow(
                        tier: tier,
                        price: content.price,
                        period: content.period,
                        billedLabel: l10n.tierCardBilledAnnually,
                        freeLabel: l10n.freeTierPrice,
                        oldPrice: content.oldPrice,
                      ),
                      const Gap(AppDimensions.spacingLg),
                      for (final bullet in content.highlights) ...[
                        _HighlightRow(label: bullet),
                        const Gap(AppDimensions.spacingSm),
                      ],
                      const Gap(AppDimensions.spacingMd),
                      DaftarButton(
                        label: isCurrentPlan
                            ? l10n.tierCardCurrentPlan
                            : content.ctaLabel,
                        onPressed: isCurrentPlan ? null : onCtaPressed,
                        variant: ctaVariant,
                        size: DaftarButtonSize.large,
                        isExpanded: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _borderColor({
    required AppTier tier,
    required bool isSelected,
    required bool isDark,
  }) {
    if (!isSelected) {
      return isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    }
    return switch (tier) {
      AppTier.free =>
        isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
      AppTier.pro => AppColors.lapis400.withValues(alpha: 0.45),
      AppTier.proPlus => AppColors.lapis400,
    };
  }

  static _PlanCardContent _contentFor(AppLocalizations l10n, AppTier tier) {
    const contest = AppConstants.kContestDisableMultiDeviceSync;
    return switch (tier) {
      AppTier.free => _PlanCardContent(
          name: l10n.tierCompareFree,
          tagline: l10n.tierCardTaglineFree,
          price: l10n.tierPriceFree,
          ctaLabel: l10n.tierCardCtaFree,
          highlights: [
            l10n.tierCardHighlightFree1,
            l10n.tierCardHighlightFree2,
            l10n.tierCardHighlightFree3,
          ],
        ),
      AppTier.pro => _PlanCardContent(
          name: l10n.tierComparePro,
          tagline: l10n.tierCardTaglinePro,
          price: l10n.tierPriceProAmount,
          period: l10n.tierPriceProPeriod,
          oldPrice: l10n.tierCardOldPricePro,
          badge: l10n.tierBadgeSavePro,
          ctaLabel: l10n.tierCardCtaPro,
          highlights: [
            l10n.tierCardHighlightPro1,
            l10n.tierCardHighlightPro2,
            l10n.tierFeatureLedgerArchiving,
          ],
        ),
      AppTier.proPlus => _PlanCardContent(
          name: l10n.tierCompareProPlus,
          tagline: contest
              ? l10n.tierCardTaglineProPlusContest
              : l10n.tierCardTaglineProPlus,
          price: l10n.tierPriceProPlusAmount,
          period: l10n.tierPriceProPlusPeriod,
          oldPrice: l10n.tierCardOldPriceProPlus,
          badge: l10n.tierBadgeSaveProPlus,
          ctaLabel: l10n.tierCardCtaProPlus,
          highlights: [
            l10n.tierCardHighlightProPlus1,
            if (contest)
              l10n.tierCardHighlightProPlus2Contest
            else
              l10n.tierCardHighlightProPlus2,
            l10n.tierCardHighlightProPlus3,
          ],
        ),
    };
  }
}

final class _PlanCardContent {
  const _PlanCardContent({
    required this.name,
    required this.tagline,
    required this.price,
    required this.ctaLabel,
    required this.highlights,
    this.period,
    this.oldPrice,
    this.badge,
  });

  final String name;
  final String tagline;
  final String price;
  final String? period;
  final String? oldPrice;
  final String? badge;
  final String ctaLabel;
  final List<String> highlights;
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.label,
    this.emphasized = false,
  });

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface3 : AppColors.surface3Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: emphasized
              ? AppColors.lapis400
              : (isDark ? AppColors.borderStrong : AppColors.borderStrongLight),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.tier,
    required this.price,
    required this.billedLabel,
    required this.freeLabel,
    this.period,
    this.oldPrice,
  });

  final AppTier tier;
  final String price;
  final String? period;
  final String? oldPrice;
  final String billedLabel;
  final String freeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (tier == AppTier.free) {
      return Text(
        freeLabel,
        style: AppTextStyles.amountLarge.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: AppTextStyles.amountLarge.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (period != null)
                Text(
                  period!,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (oldPrice != null) ...[
                const Gap(AppDimensions.spacingSm),
                Text(
                  oldPrice!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Gap(AppDimensions.spacingXxs),
        Text(
          billedLabel,
          style: AppTextStyles.labelSmall.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_rounded,
          size: 18,
          color: scheme.onSurface,
        ),
        const Gap(AppDimensions.spacingSm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurface,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
