import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Subtle Pro/Pro+ micro-badge for premium settings rows.
class ProMicroBadge extends StatelessWidget {
  const ProMicroBadge({
    super.key,
    this.label,
  });

  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final text = label ?? l10n.settingsProBadgeLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surface4.withValues(alpha: 0.65)
            : AppColors.surface2Light.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(
          color: AppColors.lapis400.withValues(alpha: 0.35),
          width: AppDimensions.dividerThickness,
        ),
        boxShadow: AppGlows.premiumPro,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXxs,
        ),
        child: Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            color: isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
