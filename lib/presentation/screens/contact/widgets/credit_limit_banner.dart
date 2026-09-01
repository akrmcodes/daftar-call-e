import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/presentation/providers/balance_providers.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Premium banner that appears when a contact approaches or exceeds their
/// credit limit.
class CreditLimitBanner extends ConsumerWidget {
  /// Creates a banner for the provided contact id.
  ///
  /// When [contact] and [balances] are supplied by the parent screen, provider
  /// watches are skipped for better scroll performance.
  const CreditLimitBanner({
    required this.contactId,
    this.contact,
    this.balances,
    super.key,
  });

  /// Contact identifier used when parent does not pass [contact].
  final String contactId;

  /// Pre-resolved contact from the parent screen (optional).
  final Contact? contact;

  /// Pre-resolved balances from the parent screen (optional).
  final List<ContactBalance>? balances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    var resolvedContact = contact;
    if (resolvedContact == null) {
      final contactResult =
          ref.watch(contactByIdProvider(contactId)).asData?.value;
      resolvedContact = contactResult?.fold<Contact?>(
        (_) => null,
        (value) => value,
      );
    }

    if (resolvedContact == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final creditLimit = resolvedContact.creditLimit;
    if (creditLimit == null || creditLimit <= 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final resolvedBalances = balances ??
        ref.watch(contactBalanceProvider(contactId)).asData?.value ??
        const <ContactBalance>[];
    final relevantBalance = _selectRelevantBalance(
      resolvedBalances,
      resolvedContact.creditCurrency,
    );

    if (relevantBalance == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final outstandingDebt = -relevantBalance.netBalance;
    if (outstandingDebt <= 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final utilization = outstandingDebt / creditLimit;
    if (utilization < 0.8) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isExceeded = utilization > 1.0;
    final accentColor = isExceeded ? AppColors.error : AppColors.warning;
    final icon = isExceeded
        ? Icons.error_outline_rounded
        : Icons.warning_rounded;
    final title = l10n.notificationWarningTitle;
    final subtitle = isExceeded
        ? l10n.notificationExceededBody(resolvedContact.name)
        : l10n.notificationWarningBody(resolvedContact.name);
    final progress = utilization > 1.0 ? 1.0 : utilization;
    final percentText = _formatPercent(utilization);
    final backgroundColor = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.12 : 0.10),
      colors.surface,
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingXs,
        ),
        child: FadeSlideTransition(
          child: Semantics(
            liveRegion: true,
            child: AnimatedContainer(
              duration: AppDimensions.animationMedium,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: accentColor.withValues(
                    alpha: isDark ? 0.18 : 0.16,
                  ),
                ),
              ),
              child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.cardPadding),
                    child: Row(
                      textDirection: Directionality.of(context),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: AppDimensions.iconLarge,
                          height: AppDimensions.iconLarge,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon,
                            color: accentColor,
                            size: AppDimensions.iconMedium,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    width: AppDimensions.spacingSm,
                                  ),
                                  _ProgressChip(
                                    label: percentText,
                                    accentColor: accentColor,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingXxs),
                              Text(
                                subtitle,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusCircular,
                                ),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: colors.onSurface.withValues(
                                    alpha: isDark ? 0.08 : 0.05,
                                  ),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  ContactBalance? _selectRelevantBalance(
    List<ContactBalance> balances,
    String? creditCurrency,
  ) {
    if (balances.isEmpty) {
      return null;
    }

    if (creditCurrency != null && creditCurrency.trim().isNotEmpty) {
      final normalizedCurrency = creditCurrency.trim().toUpperCase();
      for (final balance in balances) {
        if (balance.currencyCode.toUpperCase() == normalizedCurrency) {
          return balance;
        }
      }

      return null;
    }

    var lowestBalance = balances.first;
    for (final balance in balances.skip(1)) {
      if (balance.netBalance < lowestBalance.netBalance) {
        lowestBalance = balance;
      }
    }

    return lowestBalance;
  }

  String _formatPercent(double utilization) {
    final percent = (utilization * 100).round();
    return '${NumberFormat.decimalPattern(AppConstants.numeralLocale).format(percent)}%';
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.label,
    required this.accentColor,
    required this.isDark,
  });

  final String label;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSm,
        vertical: AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
      ),
      child: Text(
        label,
        textDirection: ui.TextDirection.ltr,
        style: AppTextStyles.labelLarge.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
