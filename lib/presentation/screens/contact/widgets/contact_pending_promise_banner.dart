import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/domain/constants/promised_calendar_day.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/contact_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/contact/widgets/collection_promise_status_action_sheet.dart';
import 'package:daftar/presentation/screens/contact/widgets/collection_promise_status_confirm_sheet.dart';
import 'package:daftar/presentation/screens/transaction/widgets/add_transaction_dialog.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

/// Khazna promise card for the latest pending CALL-E promise on a contact.
///
/// Display-only until the merchant marks kept / broken / cancelled.
/// Kept may open payment entry — still no auto ledger write.
class ContactPendingPromiseBanner extends ConsumerWidget {
  /// Creates the card for [contactId].
  const ContactPendingPromiseBanner({
    required this.contactId,
    required this.contactName,
    super.key,
  });

  /// Drift contact id.
  final String contactId;

  /// Display name for payment entry after kept.
  final String contactName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPromises = ref.watch(pendingCollectionPromisesProvider(contactId));
    final promises = asyncPromises.value;
    if (promises == null || promises.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final latest = promises.first;
    final l10n = AppLocalizations.of(context)!;
    final amountText = _formatAmount(latest);
    final dateText = _formatDate(context, latest.promisedDate);
    if (amountText == null || dateText == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppDimensions.pagePaddingH,
          AppDimensions.spacingSm,
          AppDimensions.pagePaddingH,
          AppDimensions.spacingXs,
        ),
        child: Semantics(
          container: true,
          label: l10n.contactPendingPromiseSemantics(amountText, dateText),
          child: DaftarCard(
            variant: DaftarCardVariant.compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.contactPendingPromiseBody(amountText, dateText),
                            style: AppTextStyles.titleSmall.copyWith(
                              color: inkPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Gap(AppDimensions.spacingXs),
                          Text(
                            l10n.collectionsDeskPromiseNotPaymentSubtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: inkSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimensions.spacingSm),
                    _PromiseStatusTag(
                      label: l10n.contactPromiseStatusPending,
                      isDark: isDark,
                    ),
                  ],
                ),
                const Gap(AppDimensions.spacingMd),
                DaftarButton(
                  label: l10n.contactPromiseUpdateStatus,
                  variant: DaftarButtonVariant.secondary,
                  size: DaftarButtonSize.small,
                  isExpanded: true,
                  onPressed: () => unawaited(
                    _onUpdateStatus(
                      context: context,
                      ref: ref,
                      promise: latest,
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

  Future<void> _onUpdateStatus({
    required BuildContext context,
    required WidgetRef ref,
    required CollectionPromise promise,
  }) async {
    unawaited(HapticService.light());
    final choice = await CollectionPromiseStatusActionSheet.show(context);
    if (choice == null || !context.mounted) {
      return;
    }

    if (choice == CollectionPromiseStatus.broken ||
        choice == CollectionPromiseStatus.cancelled) {
      final confirmed = await CollectionPromiseStatusConfirmSheet.show(
        context,
        status: choice,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final result = await ref
        .read(updateCollectionPromiseStatusUseCaseProvider)
        .execute(promiseId: promise.id, status: choice);

    if (!context.mounted) {
      return;
    }

    await result.fold(
      (failure) => AppBottomSheet.showError(context, error: failure),
      (updated) async {
        if (choice == CollectionPromiseStatus.kept) {
          await showAddTransactionDialog(
            context,
            contactId: contactId,
            contactName: contactName,
            defaultCurrency: updated.currencyCode,
            initialType: TransactionType.payment,
            initialAmountMinor: updated.amountMinor,
          );
        }
      },
    );
  }

  String? _formatAmount(CollectionPromise promise) {
    final symbol = _symbolFor(promise.currencyCode);
    return MoneyUtil.formatWithSymbolForCode(
      promise.amountMinor,
      promise.currencyCode,
      symbol,
    );
  }

  String? _formatDate(BuildContext context, String promisedDate) {
    final normalized = PromisedCalendarDay.tryParse(promisedDate);
    if (normalized == null) {
      return null;
    }
    final parts = normalized.split('-');
    final date = DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  static String _symbolFor(String code) {
    final normalized = code.trim().toUpperCase();
    for (final currency in BuiltInCurrencies.all) {
      if (currency.code == normalized) {
        return currency.symbol;
      }
    }
    return normalized;
  }
}

class _PromiseStatusTag extends StatelessWidget {
  const _PromiseStatusTag({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? AppColors.surface5 : AppColors.surface4Light;
    final ink = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Container(
      height: 32,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppDimensions.spacingMd,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
