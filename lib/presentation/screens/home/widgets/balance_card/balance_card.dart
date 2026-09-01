import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_motion.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_content.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_horizon_glow.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_lapis_trace.dart';
import 'package:daftar/presentation/screens/home/widgets/balance_card/balance_card_tokens.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Khazna hero balance card — opaque stepped surface in scroll slivers.
///
/// **Surface:** `surface2` / `surface1Light` + `borderSubtle` — no glass
/// translucency. Lapis trace animation is isolated in a sibling
/// `RepaintBoundary`.
///
/// **Data binding:** When [ledgerId] is null, watches [globalBalancesProvider]
/// (home aggregate). When set, watches [ledgerBalanceSummaryProvider] for that
/// ledger. Currency selection and Lapis trace triggers are self-contained.
class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({
    this.ledgerId,
    super.key,
  });

  /// Null = app-wide aggregate (home). Non-null = ledger-scoped summary.
  final String? ledgerId;

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  bool _isExpanded = false;
  String? _selectedCurrencyCode;
  int _traceGeneration = 0;

  @override
  void initState() {
    super.initState();
    _traceGeneration = 1;
  }

  @override
  void didUpdateWidget(covariant BalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ledgerId != widget.ledgerId) {
      setState(() {
        _traceGeneration++;
        _selectedCurrencyCode = null;
      });
    }
  }

  void _selectCurrency(String code, {bool fireTrace = true}) {
    if (_selectedCurrencyCode == code) {
      return;
    }
    setState(() {
      _selectedCurrencyCode = code;
      if (fireTrace) {
        _traceGeneration++;
      }
    });
  }

  void _autoSelectCurrency(List<ContactBalance> balances) {
    if (balances.isEmpty) {
      return;
    }
    final codes = balances.map((b) => b.currencyCode).toSet();
    if (_selectedCurrencyCode == null ||
        !codes.contains(_selectedCurrencyCode)) {
      _selectCurrency(balances.first.currencyCode, fireTrace: false);
    }
  }

  void _toggleExpanded() {
    unawaited(HapticService.selection());
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  ContactBalance? _resolvePrimaryBalance(List<ContactBalance> balances) {
    if (balances.isEmpty) {
      return null;
    }

    final selected = _selectedCurrencyCode;
    if (selected != null) {
      for (final balance in balances) {
        if (balance.currencyCode == selected) {
          return balance;
        }
      }
    }

    return balances.first;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ledgerId == null) {
      ref.listen(globalBalancesProvider, (_, next) {
        next.whenData(_autoSelectCurrency);
      });
    } else {
      ref.listen(ledgerBalanceSummaryProvider(widget.ledgerId!), (_, next) {
        next.whenData(_autoSelectCurrency);
      });
    }

    final asyncBalances = widget.ledgerId == null
        ? ref.watch(globalBalancesProvider)
        : ref.watch(ledgerBalanceSummaryProvider(widget.ledgerId!));

    final balances = asyncBalances.maybeWhen(
      data: (value) => value,
      orElse: () => const <ContactBalance>[],
    );

    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;

    final onSurface = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final muted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final primaryBalance = _resolvePrimaryBalance(balances);
    final netBalance = primaryBalance?.netBalance ?? 0;
    final netColor = netBalance == 0
        ? onSurface
        : netBalance > 0
        ? (isDark ? AppColors.payment : AppColors.paymentLight)
        : (isDark ? AppColors.debt : AppColors.debtLight);

    final surfaceFill = BalanceCardTokens.surfaceFill(isDark: isDark);
    final borderColor = BalanceCardTokens.borderColor(isDark: isDark);
    final squircleRadius = BalanceCardTokens.squircleRadius;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleExpanded,
      child: ClipSmoothRect(
        radius: squircleRadius,
        child: Stack(
          children: [
            RepaintBoundary(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: surfaceFill,
                  shape: SmoothRectangleBorder(
                    borderRadius: squircleRadius,
                    side: BorderSide(
                      color: borderColor,
                      width: AppDimensions.dividerThickness,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _isExpanded ? 0.0 : 1.0,
                          duration: AppDimensions.animationMedium,
                          curve: AppMotion.curveStandard,
                          child: BalanceCardHorizonGlow(
                            isDark: isDark,
                            netBalance: netBalance,
                          ),
                        ),
                      ),
                    ),
                    if (isDark)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 1,
                        child: ColoredBox(
                          color: AppColors.innerTopHighlight,
                        ),
                      ),
                    BalanceCardContent(
                      netBalanceLabel: l10n.netBalance,
                      primaryBalance: primaryBalance,
                      balances: balances,
                      isExpanded: _isExpanded,
                      isDark: isDark,
                      muted: muted,
                      netColor: netColor,
                      selectedCurrencyCode: _selectedCurrencyCode,
                      onCurrencySelected: _selectCurrency,
                      collapsedLabel: l10n.tapToSeeBreakdown,
                      expandedLabel: l10n.hideBreakdown,
                      debtLabel: l10n.totalDebt,
                      creditLabel: l10n.totalCredit,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: BalanceCardLapisTraceBorder(
                    key: ValueKey<int>(_traceGeneration),
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
