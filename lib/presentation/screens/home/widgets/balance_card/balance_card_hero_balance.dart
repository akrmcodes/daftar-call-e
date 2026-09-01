import 'dart:ui' as ui;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:flutter/material.dart';

/// Hero balance amount with [AnimatedFlipCounter] and subdued currency code.
class BalanceCardHeroBalance extends StatelessWidget {
  const BalanceCardHeroBalance({
    required this.netBalance,
    required this.currencyCode,
    required this.decimalPlaces,
    required this.netColor,
    required this.muted,
    super.key,
  });

  final int netBalance;
  final String currencyCode;
  final int decimalPlaces;
  final Color netColor;
  final Color muted;

  static const double _heroHeight = 40;

  @override
  Widget build(BuildContext context) {
    final isPositive = netBalance > 0;
    final isNegative = netBalance < 0;
    final signPrefix = isPositive
        ? '+'
        : isNegative
        ? '−'
        : '';

    final heroStyle = AppTextStyles.amountLarge.copyWith(
      color: netColor,
    );

    return SizedBox(
      height: _heroHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          height: _heroHeight,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (signPrefix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 2),
                    child: Text(
                      signPrefix,
                      style: heroStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                AnimatedFlipCounter(
                  value: CurrencyPrecision.toMajorUnits(
                    netBalance.abs(),
                    decimalPlaces,
                  ),
                  duration: AppDimensions.animationXSlow,
                  curve: AppMotion.curveEmphasized,
                  textStyle: heroStyle,
                  fractionDigits: decimalPlaces,
                  thousandSeparator: ',',
                  mainAxisAlignment: MainAxisAlignment.start,
                  wholeDigits: 7,
                  hideLeadingZeroes: true,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  currencyCode,
                  style: AppTextStyles.amountMicro.copyWith(
                    color: muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
