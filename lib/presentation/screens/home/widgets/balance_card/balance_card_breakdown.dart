import 'dart:ui' as ui;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

/// Breakdown panel showing total debt and total payment for the selected currency.
class BalanceCardBreakdownSection extends StatelessWidget {
  const BalanceCardBreakdownSection({
    required this.balance,
    required this.decimalPlaces,
    required this.isDark,
    required this.debtLabel,
    required this.creditLabel,
    super.key,
  });

  final ContactBalance balance;
  final int decimalPlaces;
  final bool isDark;
  final String debtLabel;
  final String creditLabel;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final cardSurface =
        isDark ? AppColors.surface3 : AppColors.surface2Light;
    final borderColor = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;

    return Container(
      decoration: ShapeDecoration(
        color: cardSurface,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppDimensions.radiusSm,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: borderColor,
            width: AppDimensions.dividerThickness,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.cardPadding),
      child: Row(
        children: [
          Expanded(
            child: BalanceCardMetricTile(
              label: debtLabel,
              rawAmount: balance.totalDebt,
              decimalPlaces: decimalPlaces,
              accentColor: isDark ? AppColors.debt : AppColors.debtLight,
              muted: muted,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Container(
            width: AppDimensions.dividerThickness,
            height: 40,
            color: borderColor,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: BalanceCardMetricTile(
              label: creditLabel,
              rawAmount: balance.totalPayment,
              decimalPlaces: decimalPlaces,
              accentColor: isDark ? AppColors.payment : AppColors.paymentLight,
              muted: muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single debt or payment metric with label and animated amount.
class BalanceCardMetricTile extends StatelessWidget {
  const BalanceCardMetricTile({
    required this.label,
    required this.rawAmount,
    required this.decimalPlaces,
    required this.accentColor,
    required this.muted,
    super.key,
  });

  final String label;
  final int rawAmount;
  final int decimalPlaces;
  final Color accentColor;
  final Color muted;

  static const double _metricHeight = 24;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: muted,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        SizedBox(
          height: _metricHeight,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: AnimatedFlipCounter(
              value: CurrencyPrecision.toMajorUnits(
                rawAmount,
                decimalPlaces,
              ),
              duration: AppDimensions.animationXSlow,
              curve: AppMotion.curveEmphasized,
              textStyle: AppTextStyles.amountMedium.copyWith(
                color: accentColor,
              ),
              fractionDigits: decimalPlaces,
              thousandSeparator: ',',
              mainAxisAlignment: MainAxisAlignment.start,
              wholeDigits: 5,
              hideLeadingZeroes: true,
            ),
          ),
        ),
      ],
    );
  }
}
