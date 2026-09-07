import 'dart:async' show unawaited;
import 'dart:ui' as ui;

import 'package:daftar/app/router/app_router.dart';
import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/money_util.dart';
import 'package:daftar/domain/constants/built_in_currencies.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// HITL sheet after a debt save exceeds the contact credit limit (B-trigger).
///
/// Never auto-dials. [show] returns `true` when the merchant chooses to open
/// the credit-limit call session — Prepare the call is the only PSTN consent.
class CreditLimitCallSheet extends StatelessWidget {
  /// Creates the B-trigger confirmation sheet.
  const CreditLimitCallSheet({
    required this.contactName,
    required this.outstandingMinor,
    required this.creditLimitMinor,
    required this.currencyCode,
    super.key,
  });

  /// Display name for the contact.
  final String contactName;

  /// Outstanding debt in minor units (positive integer).
  final int outstandingMinor;

  /// Configured credit limit in minor units.
  final int creditLimitMinor;

  /// ISO currency for formatting.
  final String currencyCode;

  /// Returns `true` when the merchant taps Prepare the call.
  static Future<bool> show(
    BuildContext context, {
    required String contactName,
    required int outstandingMinor,
    required int creditLimitMinor,
    required String currencyCode,
  }) async {
    final host = rootNavigatorKey.currentContext ?? context;
    final result = await AppBottomSheet.show<bool>(
      host,
      title: AppLocalizations.of(host)!.creditLimitCallSheetTitle,
      maxHeightFactor: 0.88,
      useRootNavigator: true,
      child: CreditLimitCallSheet(
        contactName: contactName,
        outstandingMinor: outstandingMinor,
        creditLimitMinor: creditLimitMinor,
        currencyCode: currencyCode,
      ),
    );
    return result ?? false;
  }

  String _formatAmount(int minorUnits) {
    final symbol = _symbolFor(currencyCode);
    return MoneyUtil.formatWithSymbolForCode(minorUnits, currencyCode, symbol);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final accentColor = isDark ? AppColors.debt : AppColors.debtLight;
    final outstandingText = _formatAmount(outstandingMinor);
    final limitText = _formatAmount(creditLimitMinor);
    final utilization = creditLimitMinor <= 0
        ? 1.0
        : (outstandingMinor / creditLimitMinor).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: accentColor,
              size: AppDimensions.iconMedium + 4,
            ),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                l10n.creditLimitCallSheetBody(
                  contactName,
                  outstandingText,
                  limitText,
                ),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingMd),
        _AmountRow(
          label: l10n.creditLimitCallSheetOutstanding,
          amount: outstandingText,
          inkSecondary: inkSecondary,
          inkPrimary: inkPrimary,
        ),
        const Gap(AppDimensions.spacingXs),
        _AmountRow(
          label: l10n.creditLimitCallSheetLimit,
          amount: limitText,
          inkSecondary: inkSecondary,
          inkPrimary: inkPrimary,
        ),
        const Gap(AppDimensions.spacingMd),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
          child: LinearProgressIndicator(
            value: utilization,
            minHeight: 8,
            backgroundColor: (isDark ? AppColors.surface5 : AppColors.surface3Light)
                .withValues(alpha: 0.9),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        const Gap(AppDimensions.spacingLg),
        DaftarButton(
          label: l10n.creditLimitCallSheetPrepare,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.medium());
            Navigator.of(context).pop(true);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.creditLimitCallSheetNotNow,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.light());
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    required this.inkSecondary,
    required this.inkPrimary,
  });

  final String label;
  final String amount;
  final Color inkSecondary;
  final Color inkPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
          ),
        ),
        Text(
          amount,
          textDirection: ui.TextDirection.ltr,
          style: AppTextStyles.amountSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
