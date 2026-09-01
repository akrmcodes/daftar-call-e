import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/providers/import_csv_notifier.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Tappable drop-zone card for selecting or replacing a CSV file.
class ImportCsvFileZone extends StatelessWidget {
  const ImportCsvFileZone({
    required this.state,
    required this.onPickFile,
    super.key,
  });

  final ImportCsvUiState state;
  final VoidCallback onPickFile;

  bool get _isBusy => state.phase == ImportCsvPhase.importing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkSecondary =
        isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final hasFile = state.fileName != null;

    return DaftarCard(
      variant: hasFile ? DaftarCardVariant.standard : DaftarCardVariant.hero,
      onTap: _isBusy
          ? null
          : () {
              unawaited(HapticService.light());
              onPickFile();
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surface4 : AppColors.surface3Light,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(
                color: isDark
                    ? AppColors.borderSubtle
                    : AppColors.borderSubtleLight,
                width: AppDimensions.dividerThickness,
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(AppDimensions.spacingMd),
              child: Icon(
                hasFile ? Icons.description_outlined : Icons.upload_file_rounded,
                size: AppDimensions.iconLarge,
                color: inkSecondary,
              ),
            ),
          ),
          const Gap(AppDimensions.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFile
                      ? l10n.csvImportSelectedFileLabel
                      : l10n.csvImportSelectFile,
                  style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
                ),
                const Gap(AppDimensions.spacingXs),
                Text(
                  hasFile ? state.fileName! : l10n.csvImportFileZoneHint,
                  style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
                  maxLines: hasFile ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasFile && !_isBusy) ...[
                  const Gap(AppDimensions.spacingSm),
                  Text(
                    l10n.csvImportReplaceFile,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_isBusy)
            Icon(
              Icons.chevron_right_rounded,
              color: inkMuted,
            ),
        ],
      ),
    );
  }
}
