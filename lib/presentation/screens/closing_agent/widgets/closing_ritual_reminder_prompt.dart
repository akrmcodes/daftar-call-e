import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Yes / Top 5 / No after a confirmed closing plan.
class ClosingRitualReminderPrompt extends StatelessWidget {
  /// Creates the reminder prompt.
  const ClosingRitualReminderPrompt({
    required this.onChosen,
    required this.primaryIsOwned,
    super.key,
  });

  /// Merchant reminder choice.
  final ValueChanged<ClosingReminderPolicy> onChosen;

  /// When true, Yes owns the lapis glow.
  final bool primaryIsOwned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;

    return RepaintBoundary(
      child: DaftarCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.closingRitualRemindersTitle,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.closingRitualRemindersYes,
              variant: primaryIsOwned
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingReminderPolicy.all),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingRitualRemindersTop5,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingReminderPolicy.top5),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingRitualRemindersNo,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingReminderPolicy.none),
            ),
          ],
        ),
      ),
    );
  }
}
