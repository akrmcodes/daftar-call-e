import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:flutter/material.dart';

/// Khazna tag chip for dual-rail outreach assignment.
class OutreachRailBadge extends StatelessWidget {
  /// Creates a rail badge.
  const OutreachRailBadge({
    required this.rail,
    super.key,
  });

  /// Dual-rail assignment for this desk row.
  final OutreachRail rail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final surface = isDark ? AppColors.surface5 : AppColors.surface3Light;

    final label = switch (rail) {
      OutreachRail.call => l10n.collectionsDeskRailCall,
      OutreachRail.email => l10n.collectionsDeskRailEmail,
      OutreachRail.both => l10n.collectionsDeskRailBoth,
      OutreachRail.callUnavailable => l10n.collectionsDeskRailCallUnavailable,
      OutreachRail.skipped => l10n.collectionsDeskRailSkipped,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: 6,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
