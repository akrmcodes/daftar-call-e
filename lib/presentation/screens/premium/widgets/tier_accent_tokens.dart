import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:flutter/material.dart';

/// Khazna-compliant tier visuals — monochrome surfaces, lapis as light only.
abstract final class TierAccentTokens {
  /// Lapis is the sole accent; intensity scales by tier (§16 glow-as-currency).
  static Color glowColor(AppTier tier) => AppColors.lapis400;

  static double glowStrength(AppTier tier) => switch (tier) {
        AppTier.free => 0.0,
        AppTier.pro => 0.55,
        AppTier.proPlus => 1.0,
      };

  static Color topBlockColor(AppTier tier, {required bool isDark}) {
    return switch (tier) {
      AppTier.free => isDark ? AppColors.surface4 : AppColors.surface2Light,
      AppTier.pro => isDark ? AppColors.surface5 : AppColors.surface3Light,
      AppTier.proPlus => isDark ? AppColors.surface3 : AppColors.surface1Light,
    };
  }

  static Color topBlockInk(AppTier tier, {required bool isDark}) =>
      isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

  static Color cardBorder(
    AppTier tier, {
    required bool isActive,
    required bool isDark,
  }) {
    if (!isActive) {
      return isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    }
    return switch (tier) {
      AppTier.free =>
        isDark ? AppColors.borderStrong : AppColors.borderStrongLight,
      AppTier.pro => AppColors.lapis400.withValues(alpha: 0.35),
      AppTier.proPlus => AppColors.lapis400,
    };
  }

  static List<BoxShadow> cardShadows(
    AppTier tier, {
    required bool isActive,
  }) {
    if (!isActive) {
      return AppGlows.khazaFloat;
    }
    return switch (tier) {
      AppTier.free => AppGlows.khazaFloat,
      AppTier.pro => [...AppGlows.khazaFloat, ...AppGlows.premiumPro],
      AppTier.proPlus => [...AppGlows.khazaFloat, ...AppGlows.premiumProPlus],
    };
  }

  static List<Color> ambientGlowGradient(AppTier tier) {
    final strength = glowStrength(tier);
    return [
      AppColors.lapis400.withValues(alpha: 0.28 * strength),
      AppColors.lapis400.withValues(alpha: 0.10 * strength),
      Colors.transparent,
    ];
  }

  static IconData tierIcon(AppTier tier) => switch (tier) {
        AppTier.free => Icons.lock_open_rounded,
        AppTier.pro => Icons.bolt_rounded,
        AppTier.proPlus => Icons.auto_awesome_rounded,
      };
}
