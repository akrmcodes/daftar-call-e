import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Confirmation before marking a promise broken or cancelled.
class CollectionPromiseStatusConfirmSheet extends StatelessWidget {
  const CollectionPromiseStatusConfirmSheet({
    required this.status,
    super.key,
  });

  final CollectionPromiseStatus status;

  /// Returns `true` when the merchant confirms.
  static Future<bool> show(
    BuildContext context, {
    required CollectionPromiseStatus status,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final title = status == CollectionPromiseStatus.broken
        ? l10n.contactPromiseMarkBrokenConfirmTitle
        : l10n.contactPromiseMarkCancelledConfirmTitle;

    final result = await AppBottomSheet.show<bool>(
      context,
      title: title,
      maxHeightFactor: 0.55,
      scrollable: false,
      child: CollectionPromiseStatusConfirmSheet(status: status),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.theme.brightness == Brightness.dark;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final body = status == CollectionPromiseStatus.broken
        ? l10n.contactPromiseMarkBrokenConfirmBody
        : l10n.contactPromiseMarkCancelledConfirmBody;
    final actionLabel = status == CollectionPromiseStatus.broken
        ? l10n.contactPromiseStatusBroken
        : l10n.contactPromiseStatusCancelled;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: inkSecondary,
            height: 1.45,
          ),
        ),
        const Gap(AppDimensions.spacingXxl),
        DaftarButton(
          label: actionLabel,
          variant: DaftarButtonVariant.destructive,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.medium());
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
