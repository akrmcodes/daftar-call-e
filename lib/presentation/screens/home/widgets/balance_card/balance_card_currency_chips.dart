import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/presentation/shared/widgets/daftar_tap_target.dart';
import 'package:flutter/material.dart';

/// Horizontal scrollable row of currency selector chips.
class BalanceCardCurrencyChips extends StatelessWidget {
  const BalanceCardCurrencyChips({
    required this.balances,
    required this.selectedCurrencyCode,
    required this.onSelected,
    required this.isDark,
    super.key,
  });

  final List<ContactBalance> balances;
  final String? selectedCurrencyCode;
  final ValueChanged<String> onSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final onSurface = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final lapis = isDark ? AppColors.lapis400 : AppColors.lapis500;

    return SizedBox(
      height: AppDimensions.minTapTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsetsDirectional.zero,
        itemCount: balances.length,
        separatorBuilder: (_, index) =>
            const SizedBox(width: AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          final balance = balances[index];
          final code = balance.currencyCode;
          final isSelected = code == selectedCurrencyCode;

          return Material(
            key: ValueKey<String>('currency_chip_$code'),
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            child: InkWell(
              onTap: () {
                unawaited(HapticService.selection());
                onSelected(code);
              },
              borderRadius: BorderRadius.circular(
                AppDimensions.radiusCircular,
              ),
              splashColor: lapis.withValues(alpha: 0.08),
              highlightColor: lapis.withValues(alpha: 0.04),
              child: DaftarTapTarget(
                child: AnimatedContainer(
                  duration: AppDimensions.animationFast,
                  curve: AppMotion.curveEnter,
                  height: 32,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                              ? AppColors.surface4
                              : AppColors.surface3Light)
                        : (isDark
                              ? AppColors.surface3.withValues(alpha: 0.5)
                              : AppColors.surface2Light.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusCircular,
                    ),
                    border: Border.all(
                      color: isSelected
                          ? lapis.withValues(alpha: 0.5)
                          : (isDark
                                ? AppColors.borderSubtle
                                : AppColors.borderSubtleLight),
                      width: AppDimensions.dividerThickness,
                    ),
                  ),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: AppDimensions.animationFast,
                      curve: AppMotion.curveEnter,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected ? onSurface : muted,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                      child: Text(code),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
