import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Shared geometry and surface tokens for the balance card family.
abstract final class BalanceCardTokens {
  static final squircleRadius = SmoothBorderRadius(
    cornerRadius: AppDimensions.radiusMd,
    cornerSmoothing: 0.6,
  );

  static Color surfaceFill({required bool isDark}) =>
      isDark ? AppColors.surface2 : AppColors.surface1Light;

  static Color borderColor({required bool isDark}) =>
      isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
}
