import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Confirmation sheet before deleting a contact and its transactions.
class ContactDeleteConfirmSheet extends StatelessWidget {
  const ContactDeleteConfirmSheet({
    required this.contactName,
    required this.transactionsCount,
    super.key,
  });

  final String contactName;
  final int transactionsCount;

  /// Returns `true` when the user confirms deletion.
  static Future<bool> show(
    BuildContext context, {
    required String contactName,
    required int transactionsCount,
  }) async {
    final result = await AppBottomSheet.show<bool>(
      context,
      title: AppLocalizations.of(context)!.contactDeleteConfirmTitle,
      maxHeightFactor: 0.55,
      scrollable: false,
      child: ContactDeleteConfirmSheet(
        contactName: contactName,
        transactionsCount: transactionsCount,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final warningColor = isDark ? AppColors.debt : AppColors.debtLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: warningColor,
              size: AppDimensions.iconMedium + 4,
            ),
            const Gap(AppDimensions.spacingMd),
            Expanded(
              child: Text(
                l10n.contactDeleteConfirmBody,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: inkSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          contactName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleSmall.copyWith(
            color: inkPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (transactionsCount > 0) ...[
          const Gap(AppDimensions.spacingXs),
          Text(
            l10n.transactionsCount(transactionsCount),
            style: AppTextStyles.bodySmall.copyWith(
              color: inkSecondary,
              fontFamily: AppTextStyles.latinFontFamily,
            ),
          ),
        ],
        const Gap(AppDimensions.spacingXxl),
        DaftarButton(
          label: l10n.contactDeleteConfirmAction,
          variant: DaftarButtonVariant.destructive,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.deleteConfirmed());
            Navigator.of(context).pop(true);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.backupRestoreCancel,
          variant: DaftarButtonVariant.tertiary,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
