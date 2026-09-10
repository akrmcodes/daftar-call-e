import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Action sheet to mark a pending CALL-E promise kept, broken, or cancelled.
class CollectionPromiseStatusActionSheet extends StatelessWidget {
  const CollectionPromiseStatusActionSheet({super.key});

  /// Returns the chosen terminal status, or null when dismissed.
  static Future<CollectionPromiseStatus?> show(BuildContext context) {
    return AppBottomSheet.show<CollectionPromiseStatus>(
      context,
      title: AppLocalizations.of(context)!.contactPromiseStatusActionSheetTitle,
      maxHeightFactor: 0.5,
      scrollable: false,
      child: const CollectionPromiseStatusActionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DaftarButton(
          label: l10n.contactPromiseStatusKept,
          variant: DaftarButtonVariant.secondary,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.light());
            Navigator.of(context).pop(CollectionPromiseStatus.kept);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.contactPromiseStatusBroken,
          variant: DaftarButtonVariant.destructiveOutlined,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.light());
            Navigator.of(context).pop(CollectionPromiseStatus.broken);
          },
        ),
        const Gap(AppDimensions.spacingMd),
        DaftarButton(
          label: l10n.contactPromiseStatusCancelled,
          variant: DaftarButtonVariant.destructiveOutlined,
          isExpanded: true,
          onPressed: () {
            unawaited(HapticService.light());
            Navigator.of(context).pop(CollectionPromiseStatus.cancelled);
          },
        ),
      ],
    );
  }
}
