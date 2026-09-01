import 'dart:ui' as ui;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Glass upgrade banner for free-tier users on the store identity screen.
class MerchantBrandingUpgradeBanner extends StatelessWidget {
  const MerchantBrandingUpgradeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final borderColor = isDark
        ? AppColors.glassBorder
        : AppColors.glassBorderLight;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: AppDimensions.spacingXl,
      ),
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
          cornerRadius: AppDimensions.radiusLg,
          cornerSmoothing: 0.6,
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: glassFill,
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: AppGlows.premiumPro,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppDimensions.iconLarge,
                        height: AppDimensions.iconLarge,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.lapis400.withValues(alpha: 0.45),
                            width: 0.5,
                          ),
                          boxShadow: AppGlows.haloSm,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: isDark
                              ? AppColors.inkPrimary
                              : AppColors.inkPrimaryLight,
                          size: AppDimensions.iconMedium,
                        ),
                      ),
                      const Gap(AppDimensions.spacingMd),
                      Expanded(
                        child: Text(
                          l10n.merchantBrandingUpgradeTitle,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: isDark
                                ? AppColors.inkPrimary
                                : AppColors.inkPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppDimensions.spacingSm),
                  Text(
                    l10n.merchantBrandingUpgradeSubtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight,
                    ),
                  ),
                  const Gap(AppDimensions.spacingXl),
                  DaftarButton(
                    label: l10n.merchantBrandingUpgradeCta,
                    onPressed: () => context.pushNamed(RouteNames.activation),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
