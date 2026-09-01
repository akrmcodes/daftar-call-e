import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
/// Full-bleed per-currency balance carousel for a contact.
///
/// Uses [PageController.viewportFraction] for inter-card peek — never outer
/// horizontal padding on the scroll viewport (that clips cards mid-screen).
class BalanceSummary extends StatefulWidget {
  const BalanceSummary({
    required this.balances,
    required this.isDark,
    super.key,
  });

  final List<ContactBalance> balances;
  final bool isDark;

  @override
  State<BalanceSummary> createState() => _BalanceSummaryState();
}

class _BalanceSummaryState extends State<BalanceSummary> {
  static const double _carouselHeight = 188;
  static const double _viewportFraction = 0.88;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.balances.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.balances.length == 1) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.pagePaddingH,
        ),
        child: _BalanceSummaryCard(
          balance: widget.balances.first,
          isDark: widget.isDark,
        ),
      );
    }

    return SizedBox(
      height: _carouselHeight,
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        clipBehavior: Clip.none,
        itemCount: widget.balances.length,
        itemBuilder: (context, index) {
          final isFirst = index == 0;
          final isLast = index == widget.balances.length - 1;
          return Padding(
            padding: EdgeInsetsDirectional.only(
              start: isFirst
                  ? AppDimensions.pagePaddingH
                  : AppDimensions.spacingSm,
              end: isLast
                  ? AppDimensions.pagePaddingH
                  : AppDimensions.spacingSm,
            ),
            child: _BalanceSummaryCard(
              balance: widget.balances[index],
              isDark: widget.isDark,
            ),
          );
        },
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({
    required this.balance,
    required this.isDark,
  });

  final ContactBalance balance;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final netBalance = balance.netBalance;
    final amountColor = netBalance > 0
        ? (isDark ? AppColors.payment : AppColors.paymentLight)
        : netBalance < 0
        ? (isDark ? AppColors.debt : AppColors.debtLight)
        : (isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight);
    final glassFill = isDark ? AppColors.glassFill : AppColors.glassFillLight;
    final glassBorder = isDark
        ? AppColors.borderSubtle
        : AppColors.borderSubtleLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusXl,
      cornerSmoothing: 0.6,
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(borderRadius: squircleRadius),
        shadows: isDark ? AppGlows.khazaFloat : AppGlows.shadowFloat,
      ),
      child: ClipSmoothRect(
        radius: squircleRadius,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: glassFill,
            shape: SmoothRectangleBorder(
              borderRadius: squircleRadius,
              side: BorderSide(
                color: glassBorder,
                width: AppDimensions.dividerThickness,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _CurrencyPill(
                      currencyCode: balance.currencyCode,
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Text(
                      l10n.netBalance,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: inkMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _formatSignedAmount(netBalance, balance.currencyCode),
                        style: AppTextStyles.amountLarge.copyWith(
                          color: amountColor,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Container(
                  height: AppDimensions.dividerThickness,
                  color: glassBorder,
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                Row(
                  children: [
                    Expanded(
                      child: _MetricColumn(
                        label: l10n.totalDebt,
                        value: _formatAmount(
                          balance.totalDebt,
                          balance.currencyCode,
                        ),
                        valueColor: isDark ? AppColors.debt : AppColors.debtLight,
                        labelColor: inkSecondary,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: _MetricColumn(
                        label: l10n.totalCredit,
                        value: _formatAmount(
                          balance.totalPayment,
                          balance.currencyCode,
                        ),
                        valueColor: isDark
                            ? AppColors.payment
                            : AppColors.paymentLight,
                        labelColor: inkSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({
    required this.currencyCode,
    required this.isDark,
  });

  final String currencyCode;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface4 : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        border: Border.all(
          color: isDark
              ? AppColors.borderSubtle
              : AppColors.borderSubtleLight,
          width: AppDimensions.dividerThickness,
        ),
      ),
      child: Text(
        currencyCode,
        style: AppTextStyles.labelLarge.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall.copyWith(color: labelColor),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          value,
          maxLines: 1,
          textDirection: ui.TextDirection.ltr,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.amountSmall.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _formatAmount(int amount, String currencyCode) {
  return MoneyUtil.formatMinorUnitsForCode(amount.abs(), currencyCode);
}

String _formatSignedAmount(int amount, String currencyCode) {
  if (amount == 0) {
    return MoneyUtil.formatMinorUnitsForCode(0, currencyCode);
  }

  final formattedAmount = _formatAmount(amount, currencyCode);
  return amount > 0 ? '+$formattedAmount' : '-$formattedAmount';
}
