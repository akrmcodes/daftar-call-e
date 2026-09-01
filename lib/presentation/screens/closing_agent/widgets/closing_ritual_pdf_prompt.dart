import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// None / Selective / Selected — stored for Collections Desk, not executed.
class ClosingRitualPdfPrompt extends StatelessWidget {
  /// Creates the PDF policy prompt.
  const ClosingRitualPdfPrompt({
    required this.onChosen,
    required this.primaryIsOwned,
    super.key,
  });

  /// Merchant PDF choice.
  final ValueChanged<ClosingPdfPolicy> onChosen;

  /// When true, Selected owns the lapis glow.
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
              l10n.closingRitualPdfsTitle,
              style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            ),
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.closingRitualPdfsSelected,
              variant: primaryIsOwned
                  ? DaftarButtonVariant.primary
                  : DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingPdfPolicy.allInSet),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingRitualPdfsSelective,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingPdfPolicy.selective),
            ),
            const Gap(AppDimensions.spacingSm),
            DaftarButton(
              label: l10n.closingRitualPdfsNone,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: () => onChosen(ClosingPdfPolicy.none),
            ),
          ],
        ),
      ),
    );
  }
}
