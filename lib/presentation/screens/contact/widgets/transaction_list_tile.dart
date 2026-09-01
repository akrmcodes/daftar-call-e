import 'dart:async';
import 'dart:ui' as ui;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/shared/widgets/list_tile_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Apple Card–grade transaction row — strict ink hierarchy, LTR amounts/dates.
///
/// Height is locked to [AppDimensions.transactionListTileExtent] so parent
/// fixed-extent slivers never overflow.
class TransactionListTile extends StatefulWidget {
  const TransactionListTile({
    required this.transaction,
    this.onTap,
    this.onDismissed,
    this.swipeEnabled = false,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final ValueChanged<Transaction>? onDismissed;
  final bool swipeEnabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<TransactionListTile> createState() => _TransactionListTileState();
}

class _TransactionListTileState extends State<TransactionListTile> {
  bool _pressed = false;

  /// Row budget inside vertical padding — must match tile extent token.
  static const double _contentHeight =
      AppDimensions.transactionListTileExtent -
      AppDimensions.spacingLg * 2;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final isDebt = widget.transaction.type == TransactionType.debt;
    final inkPrimary = isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    final typeColor = isDebt
        ? (isDark ? AppColors.debt : AppColors.debtLight)
        : (isDark ? AppColors.payment : AppColors.paymentLight);
    final typeContainer = isDebt
        ? (isDark ? AppColors.debtContainer : AppColors.debtContainerLight)
        : (isDark
              ? AppColors.paymentContainer
              : AppColors.paymentContainerLight);

    final dateText = _formatTransactionDate(widget.transaction.transactionDate);
    final amountText = _formatAmount(
      widget.transaction.amount,
      widget.transaction.currency,
      isDebt,
    );
    final originalDirectionality = Directionality.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasMenu = widget.onEdit != null || widget.onDelete != null;

    final row = Directionality(
      textDirection: originalDirectionality,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) {
                setState(() => _pressed = true);
                unawaited(HapticService.light());
              },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: AppDimensions.animationFast,
          curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppDimensions.pagePaddingH,
              AppDimensions.spacingLg,
              AppDimensions.pagePaddingH,
              AppDimensions.spacingLg,
            ),
            child: SizedBox(
              height: _contentHeight,
              child: Row(
                children: [
                  _TypeIndicator(
                    isDebt: isDebt,
                    color: typeColor,
                    containerColor: typeContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: _DetailsColumn(
                      itemName: widget.transaction.itemName,
                      description: widget.transaction.description,
                      dateText: dateText,
                      inkPrimary: inkPrimary,
                      inkSecondary: inkSecondary,
                      inkMuted: inkMuted,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  _AmountColumn(
                    amountText: amountText,
                    currency: widget.transaction.currency,
                    color: typeColor,
                    inkMuted: inkMuted,
                  ),
                  if (hasMenu) ...[
                    const SizedBox(width: AppDimensions.spacingXxs),
                    ListTileActionMenu(
                      menuSemanticsLabel: l10n.editTransaction,
                      isDark: isDark,
                      onEdit: widget.onEdit,
                      onDelete: widget.onDelete,
                      editLabel: l10n.editTransaction,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final content = Directionality(
      textDirection: ui.TextDirection.ltr,
      child: widget.swipeEnabled
          ? Dismissible(
              key: ValueKey<String>(widget.transaction.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.pagePaddingH,
                ),
                color: AppColors.error,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onDismissed: (_) {
                unawaited(HapticService.deleteConfirmed());
                widget.onDismissed?.call(widget.transaction);
              },
              child: row,
            )
          : row,
    );

    return content;
  }
}

class _TypeIndicator extends StatelessWidget {
  const _TypeIndicator({
    required this.isDebt,
    required this.color,
    required this.containerColor,
  });

  final bool isDebt;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: containerColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        isDebt ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        size: 20,
        color: color,
      ),
    );
  }
}

class _DetailsColumn extends StatelessWidget {
  const _DetailsColumn({
    required this.dateText,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    this.itemName,
    this.description,
  });

  final String? itemName;
  final String? description;
  final String dateText;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    final hasItemName = itemName != null && itemName!.trim().isNotEmpty;
    final hasDescription =
        description != null && description!.trim().isNotEmpty;
    final title = hasItemName ? itemName!.trim() : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleMedium.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (hasDescription) ...[
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: inkSecondary,
              height: 1.2,
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          dateText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ui.TextDirection.ltr,
          style: AppTextStyles.labelMedium.copyWith(
            color: inkMuted,
            fontFamily: AppTextStyles.latinFontFamily,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.amountText,
    required this.currency,
    required this.color,
    required this.inkMuted,
  });

  final String amountText;
  final String currency;
  final Color color;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amountText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.end,
          style: AppTextStyles.amountMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          currency,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: ui.TextDirection.ltr,
          textAlign: TextAlign.end,
          style: AppTextStyles.labelSmall.copyWith(
            color: inkMuted,
            fontFamily: AppTextStyles.latinFontFamily,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

String _formatAmount(int amount, String currencyCode, bool isDebt) {
  final magnitude = MoneyUtil.formatMinorUnitsForCode(amount, currencyCode);
  return isDebt ? '-$magnitude' : '+$magnitude';
}

/// Latin numerals via explicit `en_US` locale — no post-format string mutation.
String _formatTransactionDate(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;

  if (isToday) {
    return DateFormat.jm(AppConstants.numeralLocale).format(date);
  }

  final isThisYear = date.year == now.year;

  if (isThisYear) {
    return DateFormat('d MMM, h:mm a', AppConstants.numeralLocale).format(date);
  }

  return DateFormat('d MMM yyyy', AppConstants.numeralLocale).format(date);
}
