import 'dart:async';

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// §16.5 tier upgrade celebration — bottom sheet + paired haptics.
abstract final class ActivationSuccessSheet {
  static Future<void> show(
    BuildContext context, {
    required AppTier tier,
  }) async {
    unawaited(HapticService.heavy());
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        unawaited(HapticService.light());
      }),
    );

    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tierLabel = switch (tier) {
      AppTier.proPlus => l10n.planTierProPlus,
      AppTier.pro => l10n.planTierPro,
      AppTier.free => l10n.planTierFree,
    };

    final halo = switch (tier) {
      AppTier.proPlus => AppGlows.premiumProPlus,
      AppTier.pro => AppGlows.premiumPro,
      AppTier.free => AppGlows.khazaFloat,
    };

    await AppBottomSheet.show<void>(
      context,
      title: l10n.activationSuccessTitle,
      subtitle: l10n.activationSuccessSubtitle,
      scrollable: false,
      maxHeightFactor: 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(AppDimensions.spacingMd),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.surface4 : AppColors.surface2Light,
                border: Border.all(
                  color: tier == AppTier.free
                      ? (isDark
                          ? AppColors.borderStrong
                          : AppColors.borderStrongLight)
                      : AppColors.lapis400,
                  width: 0.5,
                ),
                boxShadow: halo,
              ),
              child: Icon(
                switch (tier) {
                  AppTier.proPlus => Icons.auto_awesome_rounded,
                  AppTier.pro => Icons.bolt_rounded,
                  AppTier.free => Icons.lock_open_rounded,
                },
                size: 36,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                )
                .fadeIn(duration: 300.ms),
          ),
          const Gap(AppDimensions.spacingLg),
          Text(
            tierLabel,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Gap(AppDimensions.spacingXl),
          DaftarButton(
            label: l10n.activationSuccessDone,
            onPressed: () => Navigator.of(context).maybePop(),
            size: DaftarButtonSize.xlarge,
            isExpanded: true,
          ),
          const Gap(AppDimensions.spacingMd),
        ],
      ),
    );
  }
}
