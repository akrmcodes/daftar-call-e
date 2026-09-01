import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/activation_status.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

/// Current plan — Khazna Float card with tier-appropriate lapis halo (§16).
class PlanStatusCard extends StatelessWidget {
  const PlanStatusCard({
    required this.tier,
    this.status,
    super.key,
  });

  final AppTier tier;
  final ActivationStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.onSurface;

    final tierLabel = switch (tier) {
      AppTier.proPlus => l10n.planTierProPlus,
      AppTier.pro => l10n.planTierPro,
      AppTier.free => l10n.planTierFree,
    };

    String? subtitle;
    final expiry = status?.expiresAt;
    if (expiry != null) {
      final formatted = DateFormat.yMMMd(
        AppConstants.numeralLocale,
      ).format(expiry.toLocal());
      subtitle = l10n.planExpiresOn(formatted);
      final days = status?.daysRemaining;
      if (days != null) {
        subtitle = '${l10n.planDaysRemaining(days)}\n$subtitle';
      }
    } else if (tier != AppTier.free) {
      subtitle = l10n.planLifetime;
    }

    final cardVariant = switch (tier) {
      AppTier.proPlus => DaftarCardVariant.premium,
      AppTier.pro => DaftarCardVariant.selectable,
      AppTier.free => DaftarCardVariant.standard,
    };

    final icon = switch (tier) {
      AppTier.free => Icons.lock_open_rounded,
      AppTier.pro => Icons.bolt_rounded,
      AppTier.proPlus => Icons.auto_awesome_rounded,
    };

    final iconBorder = switch (tier) {
      AppTier.free =>
        isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
      AppTier.pro => AppColors.lapis400.withValues(alpha: 0.35),
      AppTier.proPlus => AppColors.lapis400,
    };

    return DaftarCard(
          variant: cardVariant,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surface5 : AppColors.surface3Light,
                  border: Border.all(color: iconBorder, width: 0.5),
                  boxShadow: tier == AppTier.free ? null : AppGlows.haloXs,
                ),
                child: Icon(icon, color: ink),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.planStatusTitle,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      tierLabel,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
  }
}
