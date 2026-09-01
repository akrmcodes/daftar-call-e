import 'dart:ui' as ui;

import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/archived_ledger_providers.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class ArchivedTotalCard extends ConsumerStatefulWidget {
  const ArchivedTotalCard({super.key});

  @override
  ConsumerState<ArchivedTotalCard> createState() => _ArchivedTotalCardState();
}

class _ArchivedTotalCardState extends ConsumerState<ArchivedTotalCard> {
  String? _selectedCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final asyncBalances = ref.watch(archivedVaultBalancesProvider);

    return asyncBalances.when(
      loading: () => const _ArchivedTotalSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (balances) {
        if (balances.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedCode = _resolveSelectedCurrency(balances);
        final primary = balances.firstWhere(
          (balance) => balance.currencyCode == selectedCode,
          orElse: () => balances.first,
        );
        final netBalance = primary.netBalance;
        final netColor = netBalance == 0
            ? inkMuted
            : netBalance > 0
                ? (isDark ? AppColors.payment : AppColors.paymentLight)
                : (isDark ? AppColors.debt : AppColors.debtLight);
        final decimalPlaces =
            CurrencyPrecision.decimalPlacesForCode(primary.currencyCode);

        return FadeSlideTransition(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              AppDimensions.spacingMd,
              AppDimensions.pagePaddingH,
              AppDimensions.spacingLg,
            ),
            child: DaftarCard(
              variant: DaftarCardVariant.hero,
              padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXxl),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    top: -AppDimensions.spacingSm,
                    end: -AppDimensions.spacingSm,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 72,
                      color: inkMuted.withValues(alpha: isDark ? 0.12 : 0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.ac_unit_rounded,
                            size: 14,
                            color: inkMuted,
                          ),
                          const Gap(AppDimensions.spacingXxs),
                          Text(
                            l10n.archivedTotalLabel,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: inkMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppDimensions.spacingSm),
                      _FrozenHeroBalance(
                        netBalance: netBalance,
                        currencyCode: primary.currencyCode,
                        decimalPlaces: decimalPlaces,
                        netColor: netColor,
                        muted: inkMuted,
                      ),
                      if (balances.length > 1) ...[
                        const Gap(AppDimensions.spacingMd),
                        Wrap(
                          spacing: AppDimensions.spacingXs,
                          runSpacing: AppDimensions.spacingXs,
                          children: [
                            for (final balance in balances)
                              _CurrencyChip(
                                balance: balance,
                                isSelected:
                                    balance.currencyCode == selectedCode,
                                isDark: isDark,
                                onTap: () => setState(
                                  () => _selectedCurrencyCode =
                                      balance.currencyCode,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _resolveSelectedCurrency(List<ContactBalance> balances) {
    final selected = _selectedCurrencyCode;
    if (selected != null &&
        balances.any((balance) => balance.currencyCode == selected)) {
      return selected;
    }
    return balances.first.currencyCode;
  }
}

class _ArchivedTotalSkeleton extends StatelessWidget {
  const _ArchivedTotalSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingLg,
      ),
      child: DaftarCard(
        variant: DaftarCardVariant.hero,
        padding: const EdgeInsetsDirectional.all(AppDimensions.spacingXxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
            ),
            const Gap(AppDimensions.spacingMd),
            Container(
              width: 180,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrozenHeroBalance extends StatelessWidget {
  const _FrozenHeroBalance({
    required this.netBalance,
    required this.currencyCode,
    required this.decimalPlaces,
    required this.netColor,
    required this.muted,
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
    final heroStyle = AppTextStyles.amountLarge.copyWith(color: netColor);

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
                      style: heroStyle.copyWith(fontWeight: FontWeight.w600),
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
                const Gap(AppDimensions.spacingSm),
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

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.balance,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final ContactBalance balance;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.lapis400
        : (isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight);
    final fillColor = isDark ? AppColors.surface3 : AppColors.surface2Light;
    final labelColor = isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Ink(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: borderColor,
              width: isSelected
                  ? AppDimensions.dividerThickness * 1.5
                  : AppDimensions.dividerThickness,
            ),
            boxShadow: isSelected ? AppGlows.haloXs : null,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppDimensions.spacingSm,
              vertical: AppDimensions.spacingXxs,
            ),
            child: Text(
              balance.currencyCode,
              style: AppTextStyles.labelSmall.copyWith(
                color: labelColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
