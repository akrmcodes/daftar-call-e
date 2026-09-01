import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Leftover Hybrid E sticky bar. Not the filmed climax or missing-email fallback.
class CollectionsSendQueueBar extends StatelessWidget {
  /// Creates the send-queue bar.
  const CollectionsSendQueueBar({
    required this.index,
    required this.total,
    required this.contactName,
    required this.isPaused,
    required this.openIsPrimary,
    required this.isBusy,
    required this.onOpen,
    required this.onSkip,
    required this.onPause,
    required this.onResume,
    super.key,
  });

  /// 1-based Sending i.
  final int index;

  /// Prepared N.
  final int total;

  /// Name of the next pending contact.
  final String contactName;

  /// When true, resume-advance is off.
  final bool isPaused;

  /// When true, Open WhatsApp owns the lapis glow.
  final bool openIsPrimary;

  /// True while an Open is in flight.
  final bool isBusy;

  /// Opens the first pending chat (human tap).
  final VoidCallback onOpen;

  /// Skips the first pending row.
  final VoidCallback onSkip;

  /// Pauses resume-advance.
  final VoidCallback onPause;

  /// Resumes resume-advance without opening WhatsApp.
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final inkSecondary = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final title = isPaused
        ? l10n.collectionsQueuePaused(index, total)
        : l10n.collectionsQueueSending(index, total);

    return RepaintBoundary(
      child: DaftarCard(
        variant: DaftarCardVariant.compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            if (contactName.isNotEmpty) ...[
              const Gap(AppDimensions.spacingXxs),
              Text(
                contactName,
                style: AppTextStyles.bodySmall.copyWith(color: inkSecondary),
              ),
            ],
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.collectionsDeskOpenWhatsApp,
              variant: openIsPrimary
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              isLoading: isBusy,
              onPressed: isBusy ? null : onOpen,
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.collectionsDeskSkip,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: isBusy ? null : onSkip,
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: isPaused
                  ? l10n.collectionsQueueResume
                  : l10n.collectionsQueuePause,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: isBusy
                  ? null
                  : (isPaused ? onResume : onPause),
            ),
          ],
        ),
      ),
    );
  }
}
