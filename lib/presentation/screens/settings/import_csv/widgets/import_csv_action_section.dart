import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/presentation/shared/animations/fade_slide_transition.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Primary import CTA — sits directly under the file picker once a CSV is loaded.
class ImportCsvStartButton extends StatelessWidget {
  const ImportCsvStartButton({
    required this.onPressed,
    required this.isLoading,
    this.disabledHint,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return FadeSlideTransition(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(AppDimensions.spacingLg),
          DaftarButton(
            label: l10n.csvImportStart,
            icon: Icons.play_arrow_rounded,
            size: DaftarButtonSize.large,
            isExpanded: true,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
          if (disabledHint != null && onPressed == null && !isLoading) ...[
            const Gap(AppDimensions.spacingSm),
            Text(
              disabledHint!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress card shown while import pipeline runs.
class ImportCsvProgressCard extends StatelessWidget {
  const ImportCsvProgressCard({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
          child: const LinearProgressIndicator(minHeight: 4),
        ),
        const Gap(AppDimensions.spacingMd),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: inkPrimary),
        ),
      ],
    );
  }
}
