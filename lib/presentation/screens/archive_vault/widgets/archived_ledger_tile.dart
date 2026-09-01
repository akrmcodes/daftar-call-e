import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/router/route_names.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_glows.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/ledger_type.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:daftar/presentation/providers/archived_ledger_providers.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/widgets/premium/ledger_archiving_gate.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ArchivedLedgerTile extends ConsumerWidget {
  const ArchivedLedgerTile({
    required this.ledger,
    super.key,
  });

  final Ledger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final contactCount =
        ref.watch(contactCountProvider(ledger.id)).value ?? 0;
    final asyncBalances = ref.watch(ledgerBalanceSummaryProvider(ledger.id));
    final controllerState = ref.watch(archiveLedgerControllerProvider);
    final activeLedgerId =
        ref.read(archiveLedgerControllerProvider.notifier).activeLedgerId;
    final isUnarchiving =
        controllerState.isLoading && activeLedgerId == ledger.id;

    final squircleRadius = SmoothBorderRadius(
      cornerRadius: AppDimensions.radiusMd,
      cornerSmoothing: 0.6,
    );

    final balances = asyncBalances.asData?.value ?? const [];
    final primaryBalance = balances.isNotEmpty ? balances.first : null;
    final balanceLabel = primaryBalance == null
        ? '—'
        : _formatFrozenBalance(
            primaryBalance.netBalance,
            primaryBalance.currencyCode,
          );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        0,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingMd,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(borderRadius: squircleRadius),
          shadows: isDark ? AppGlows.shadowFloat : AppGlows.shadowFloat,
        ),
        child: ClipSmoothRect(
          radius: squircleRadius,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: isDark ? AppColors.surface1 : AppColors.surface1Light,
              shape: SmoothRectangleBorder(
                borderRadius: squircleRadius,
                side: BorderSide(
                  color: isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight,
                  width: AppDimensions.dividerThickness,
                ),
              ),
            ),
            child: Stack(
              children: [
                PositionedDirectional(
                  top: -6,
                  end: -6,
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 72,
                    color: inkMuted.withValues(alpha: isDark ? 0.10 : 0.08),
                  ),
                ),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(
                        alpha: isDark ? 0.14 : 0.12,
                      ),
                      borderRadius: const BorderRadiusDirectional.only(
                        bottomStart: Radius.circular(AppDimensions.radiusSm),
                      ),
                      border: BorderDirectional(
                        bottom: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.22),
                        ),
                        start: BorderSide(
                          color: AppColors.warning.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppDimensions.spacingSm,
                        AppDimensions.spacingXxs,
                        AppDimensions.spacingSm,
                        AppDimensions.spacingXxs + 1,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: AppColors.warning.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      unawaited(HapticService.light());
                      unawaited(
                        context.pushNamed(
                          RouteNames.ledgerDetail,
                          pathParameters: {
                            RouteNames.ledgerIdParam: ledger.id,
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppDimensions.cardPadding,
                        AppDimensions.cardPadding,
                        AppDimensions.cardPadding,
                        AppDimensions.spacingSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FrozenLedgerIcon(
                                ledger: ledger,
                                isDark: isDark,
                              ),
                              const Gap(AppDimensions.spacingMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ledger.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        color: inkPrimary,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                      ),
                                    ),
                                    const Gap(AppDimensions.spacingXxs),
                                    Wrap(
                                      spacing: AppDimensions.spacingXs,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          l10n.ledgerAccountCount(contactCount),
                                          style: AppTextStyles.bodySmall
                                              .copyWith(color: inkSecondary),
                                        ),
                                        Text(
                                          '·',
                                          style: AppTextStyles.bodySmall
                                              .copyWith(color: inkMuted),
                                        ),
                                        Icon(
                                          Icons.lock_clock_outlined,
                                          size: 12,
                                          color: inkMuted,
                                        ),
                                        Text(
                                          l10n.archivedLedgerReadOnlyBadge,
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                            color: inkMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Gap(AppDimensions.spacingSm),
                                    Directionality(
                                      textDirection: ui.TextDirection.ltr,
                                      child: Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(
                                          balanceLabel,
                                          style: AppTextStyles.amountSmall
                                              .copyWith(
                                            color: inkSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(AppDimensions.spacingMd),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? AppColors.borderSubtle
                                      : AppColors.borderSubtleLight,
                                ),
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isUnarchiving
                                    ? null
                                    : () => _onUnarchive(context, ref),
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    top: AppDimensions.spacingSm,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isUnarchiving)
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark
                                                ? AppColors.lapis400
                                                : AppColors.lapis500,
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.unarchive_outlined,
                                          size: AppDimensions.iconSmall,
                                          color: isDark
                                              ? AppColors.lapis400
                                              : AppColors.lapis500,
                                        ),
                                      const Gap(AppDimensions.spacingSm),
                                      Text(
                                        l10n.unarchiveLedgerAction,
                                        style: AppTextStyles.labelLarge.copyWith(
                                          color: isDark
                                              ? AppColors.inkPrimary
                                              : AppColors.inkPrimaryLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onUnarchive(BuildContext context, WidgetRef ref) async {
    final unlocked = await LedgerArchivingGate.ensureUnlocked(context, ref);
    if (!unlocked) {
      return;
    }
    unawaited(HapticService.light());
    await ref
        .read(archiveLedgerControllerProvider.notifier)
        .unarchive(ledger.id);
  }
}

class _FrozenLedgerIcon extends StatelessWidget {
  const _FrozenLedgerIcon({
    required this.ledger,
    required this.isDark,
  });

  final Ledger ledger;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final icon = _resolveLedgerIcon(ledger.icon, ledger.type);
    final tint = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface2 : AppColors.surface2Light,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(
          color: isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight,
        ),
      ),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: tint, size: AppDimensions.iconMedium),
      ),
    );
  }
}

String _formatFrozenBalance(int netBalance, String currencyCode) {
  final decimalPlaces = CurrencyPrecision.decimalPlacesForCode(currencyCode);
  final prefix = netBalance > 0
      ? '+'
      : netBalance < 0
          ? '−'
          : '';
  final formatted = MoneyUtil.formatAmount(netBalance.abs(), decimalPlaces);
  return '$prefix$formatted $currencyCode';
}

IconData _resolveLedgerIcon(String iconName, LedgerType ledgerType) {
  final normalized = iconName.trim().toLowerCase();

  switch (normalized) {
    case 'customers':
    case 'people':
    case 'people_alt_rounded':
    case 'group_rounded':
      return Icons.people_alt_rounded;
    case 'suppliers':
    case 'local_shipping_rounded':
    case 'delivery_dining_rounded':
      return Icons.local_shipping_rounded;
    case 'personal':
    case 'person_rounded':
    case 'person_outline_rounded':
      return Icons.person_rounded;
    case 'custom':
    case 'folder_special_rounded':
    case 'bookmark_rounded':
      return Icons.folder_special_rounded;
    case 'storefront_rounded':
    case 'store_rounded':
      return Icons.storefront_rounded;
    case 'receipt_long_rounded':
    case 'receipt_rounded':
      return Icons.receipt_long_rounded;
    case 'shopping_bag_rounded':
    case 'shopping_cart_rounded':
      return Icons.shopping_bag_rounded;
    case 'account_balance_wallet_rounded':
    case 'wallet_rounded':
      return Icons.account_balance_wallet_rounded;
    case 'work_outline_rounded':
    case 'business_center_rounded':
      return Icons.work_outline_rounded;
    case 'home_work_rounded':
      return Icons.home_work_rounded;
    case 'savings_rounded':
      return Icons.savings_rounded;
    case 'handshake_rounded':
      return Icons.handshake_rounded;
    default:
      return _fallbackLedgerIcon(ledgerType);
  }
}

IconData _fallbackLedgerIcon(LedgerType ledgerType) {
  switch (ledgerType) {
    case LedgerType.customers:
      return Icons.people_alt_rounded;
    case LedgerType.suppliers:
      return Icons.local_shipping_rounded;
    case LedgerType.personal:
      return Icons.person_rounded;
    case LedgerType.custom:
      return Icons.folder_special_rounded;
  }
}
