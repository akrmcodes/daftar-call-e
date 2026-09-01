import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Segmented encoding picker — replaces dropdown for clearer Arabic/UTF-8 choice.
class ImportCsvEncodingSelector extends StatelessWidget {
  const ImportCsvEncodingSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final CsvDecodingMode value;
  final ValueChanged<CsvDecodingMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    return DaftarCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.csvImportEncoding,
            style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
          ),
          const Gap(AppDimensions.spacingLg),
          LayoutBuilder(
            builder: (context, constraints) {
              final useVertical = constraints.maxWidth < 340;
              if (useVertical) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final mode in CsvDecodingMode.values) ...[
                      _EncodingChip(
                        mode: mode,
                        isSelected: value == mode,
                        label: _label(l10n, mode),
                        onTap: () => _select(mode),
                      ),
                      if (mode != CsvDecodingMode.values.last)
                        const Gap(AppDimensions.spacingSm),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < CsvDecodingMode.values.length; i++) ...[
                    if (i > 0) const Gap(AppDimensions.spacingSm),
                    Expanded(
                      child: _EncodingChip(
                        mode: CsvDecodingMode.values[i],
                        isSelected: value == CsvDecodingMode.values[i],
                        label: _label(l10n, CsvDecodingMode.values[i]),
                        onTap: () => _select(CsvDecodingMode.values[i]),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _select(CsvDecodingMode mode) {
    if (mode == value) {
      return;
    }
    unawaited(HapticService.selection());
    onChanged(mode);
  }

  String _label(AppLocalizations l10n, CsvDecodingMode mode) {
    return switch (mode) {
      CsvDecodingMode.auto => l10n.csvEncodingAuto,
      CsvDecodingMode.utf8 => l10n.csvEncodingUtf8,
      CsvDecodingMode.windows1256 => l10n.csvEncodingWindows1256,
    };
  }
}

class _EncodingChip extends StatelessWidget {
  const _EncodingChip({
    required this.mode,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final CsvDecodingMode mode;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final surface = isDark ? AppColors.surface5 : AppColors.surface3Light;
    final border = isDark ? AppColors.borderStrong : AppColors.borderStrongLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            color: isSelected ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isSelected
                  ? border
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
              width: isSelected ? 1.5 : AppDimensions.dividerThickness,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? inkPrimary : inkMuted,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
