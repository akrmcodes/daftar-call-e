import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_breakdown.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_currency_chips.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_expand_hint.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_hero_balance.dart';
import 'package:flutter/material.dart';

/// Scrollable content column inside the balance card body.
class BalanceCardContent extends StatelessWidget {
  const BalanceCardContent({
    required this.netBalanceLabel,
    required this.primaryBalance,
    required this.balances,
    required this.isExpanded,
    required this.isDark,
    required this.muted,
    required this.netColor,
    required this.selectedCurrencyCode,
    required this.onCurrencySelected,
    required this.collapsedLabel,
    required this.expandedLabel,
    required this.debtLabel,
    required this.creditLabel,
    super.key,
  });

  final String netBalanceLabel;
  final ContactBalance? primaryBalance;
  final List<ContactBalance> balances;
  final bool isExpanded;
  final bool isDark;
  final Color muted;
  final Color netColor;
  final String? selectedCurrencyCode;
  final ValueChanged<String> onCurrencySelected;
  final String collapsedLabel;
  final String expandedLabel;
  final String debtLabel;
  final String creditLabel;

  @override
  Widget build(BuildContext context) {
    final currencyCode = primaryBalance?.currencyCode ?? 'YER';
    final decimalPlaces = CurrencyPrecision.decimalPlacesForCode(currencyCode);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.spacingXl,
        AppDimensions.spacingXl,
        AppDimensions.spacingXl,
        AppDimensions.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            netBalanceLabel,
            style: AppTextStyles.labelMedium.copyWith(
              color: muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          BalanceCardHeroBalance(
            netBalance: primaryBalance?.netBalance ?? 0,
            currencyCode: primaryBalance?.currencyCode ?? '--',
            decimalPlaces: decimalPlaces,
            netColor: netColor,
            muted: muted,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          BalanceCardExpandHint(
            isExpanded: isExpanded,
            collapsedLabel: collapsedLabel,
            expandedLabel: expandedLabel,
            mutedColor: muted.withValues(alpha: 0.6),
          ),
          if (balances.length > 1) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: BalanceCardCurrencyChips(
                balances: balances,
                selectedCurrencyCode: selectedCurrencyCode,
                onSelected: onCurrencySelected,
                isDark: isDark,
              ),
            ),
          ],
          AnimatedSize(
            duration: AppDimensions.animationMedium,
            curve: AppMotion.curveEnter,
            alignment: Alignment.topCenter,
            child: isExpanded && primaryBalance != null
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: AppDimensions.spacingLg,
                    ),
                    child: BalanceCardBreakdownSection(
                      balance: primaryBalance!,
                      decimalPlaces: CurrencyPrecision.decimalPlacesForCode(
                        primaryBalance!.currencyCode,
                      ),
                      isDark: isDark,
                      debtLabel: debtLabel,
                      creditLabel: creditLabel,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
