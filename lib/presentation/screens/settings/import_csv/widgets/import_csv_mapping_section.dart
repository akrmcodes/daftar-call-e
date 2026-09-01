import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/application/import/import_csv_use_case.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Column-mapping grid with bottom-sheet pickers and inline sample previews.
class ImportCsvMappingSection extends StatelessWidget {
  const ImportCsvMappingSection({
    required this.headers,
    required this.previewRows,
    required this.columnMapping,
    required this.onMappingChanged,
    super.key,
  });

  final List<String> headers;
  final List<List<String>> previewRows;
  final Map<String, int> columnMapping;
  final void Function(String fieldKey, int columnIndex) onMappingChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.csvImportMappingSection,
          style: AppTextStyles.titleMedium.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingLg),
        Text(
          l10n.csvImportRequiredFieldsLabel,
          style: AppTextStyles.labelLarge.copyWith(
            color: isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        for (var i = 0; i < CsvImportColumn.requiredImportFields.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppDimensions.spacingMd,
            ),
            child: ImportCsvMappingField(
              fieldKey: CsvImportColumn.requiredImportFields[i],
              headers: headers,
              previewRows: previewRows,
              selectedIndex:
                  columnMapping[CsvImportColumn.requiredImportFields[i]] ?? -1,
              isRequired: true,
              onSelected: (idx) => onMappingChanged(
                CsvImportColumn.requiredImportFields[i],
                idx,
              ),
            ),
          ),
        const Gap(AppDimensions.spacingMd),
        Text(
          l10n.csvImportOptionalFieldsLabel,
          style: AppTextStyles.labelLarge.copyWith(
            color: isDark ? AppColors.inkSecondary : AppColors.inkSecondaryLight,
          ),
        ),
        const Gap(AppDimensions.spacingSm),
        for (var i = 0; i < CsvImportColumn.optionalImportFields.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              bottom: AppDimensions.spacingMd,
            ),
            child: ImportCsvMappingField(
              fieldKey: CsvImportColumn.optionalImportFields[i],
              headers: headers,
              previewRows: previewRows,
              selectedIndex:
                  columnMapping[CsvImportColumn.optionalImportFields[i]] ?? -1,
              isRequired: false,
              onSelected: (idx) => onMappingChanged(
                CsvImportColumn.optionalImportFields[i],
                idx,
              ),
            ),
          ),
      ],
    );
  }
}

class ImportCsvMappingField extends StatelessWidget {
  const ImportCsvMappingField({
    required this.fieldKey,
    required this.headers,
    required this.previewRows,
    required this.selectedIndex,
    required this.isRequired,
    required this.onSelected,
    super.key,
  });

  final String fieldKey;
  final List<String> headers;
  final List<List<String>> previewRows;
  final int selectedIndex;
  final bool isRequired;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final isMapped = selectedIndex >= 0 && selectedIndex < headers.length;
    final selectedLabel = isMapped
        ? (headers[selectedIndex].isEmpty ? '—' : headers[selectedIndex])
        : l10n.csvImportColumnHint;

    return DaftarCard(
      variant: DaftarCardVariant.compact,
      onTap: () => _openPicker(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _fieldLabel(l10n, fieldKey),
                  style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
                ),
              ),
              if (isRequired)
                _RequiredBadge(isMapped: isMapped)
              else if (!isMapped)
                Text(
                  l10n.csvImportColumnNone,
                  style: AppTextStyles.labelSmall.copyWith(color: inkMuted),
                ),
            ],
          ),
          const Gap(AppDimensions.spacingSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isMapped ? inkPrimary : inkMuted,
                    fontFamily: isMapped ? AppTextStyles.latinFontFamily : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.unfold_more_rounded, color: inkMuted, size: 20),
            ],
          ),
          if (isMapped) ...[
            const Gap(AppDimensions.spacingSm),
            _SampleChips(
              previewRows: previewRows,
              columnIndex: selectedIndex,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.light();
    if (!context.mounted) {
      return;
    }

    final picked = await AppBottomSheet.show<int>(
      context,
      title: _fieldLabel(l10n, fieldKey),
      subtitle: l10n.csvImportColumnHint,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: headers.length + (isRequired ? 0 : 1),
        separatorBuilder: (context, index) => const Gap(AppDimensions.spacingXs),
        itemBuilder: (context, index) {
          if (!isRequired && index == 0) {
            return _PickerTile(
              label: l10n.csvImportColumnNone,
              isSelected: selectedIndex < 0,
              onTap: () => Navigator.of(context).pop(-1),
            );
          }

          final colIndex = isRequired ? index : index - 1;
          final header = headers[colIndex];
          return _PickerTile(
            label: header.isEmpty ? '—' : header,
            isSelected: selectedIndex == colIndex,
            samples: previewRows
                .map((row) => colIndex < row.length ? row[colIndex] : '')
                .where((s) => s.trim().isNotEmpty)
                .take(2)
                .toList(growable: false),
            onTap: () => Navigator.of(context).pop(colIndex),
          );
        },
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  String _fieldLabel(AppLocalizations l10n, String key) {
    return switch (key) {
      CsvImportColumn.nameKey => l10n.name,
      CsvImportColumn.phoneKey => l10n.phoneNumber,
      CsvImportColumn.amountKey => l10n.amount,
      CsvImportColumn.typeKey => l10n.type,
      CsvImportColumn.currencyKey => l10n.currency,
      CsvImportColumn.dateKey => l10n.date,
      CsvImportColumn.descriptionKey => l10n.description,
      CsvImportColumn.itemNameKey => l10n.itemName,
      _ => key,
    };
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge({required this.isMapped});

  final bool isMapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isMapped
        ? (isDark ? AppColors.payment : AppColors.paymentLight)
        : (isDark ? AppColors.warning : AppColors.warningLight);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppDimensions.spacingSm,
          vertical: AppDimensions.spacingXxs,
        ),
        child: Icon(
          isMapped ? Icons.check_rounded : Icons.priority_high_rounded,
          size: 14,
          color: color,
        ),
      ),
    );
  }
}

class _SampleChips extends StatelessWidget {
  const _SampleChips({
    required this.previewRows,
    required this.columnIndex,
  });

  final List<List<String>> previewRows;
  final int columnIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final samples = previewRows
        .map((row) => columnIndex < row.length ? row[columnIndex] : '')
        .where((s) => s.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);

    if (samples.isEmpty) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Wrap(
        spacing: AppDimensions.spacingXs,
        runSpacing: AppDimensions.spacingXs,
        children: [
          for (final sample in samples)
            DecoratedBox(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface5 : AppColors.surface3Light,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppDimensions.spacingSm,
                  vertical: AppDimensions.spacingXxs,
                ),
                child: Text(
                  sample,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: inkMuted,
                    fontFamily: AppTextStyles.latinFontFamily,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.samples = const [],
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final List<String> samples;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final surface = isDark ? AppColors.surface4 : AppColors.surface2Light;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticService.selection());
          onTap();
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          padding: const EdgeInsetsDirectional.all(AppDimensions.spacingMd),
          decoration: BoxDecoration(
            color: isSelected ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(
              color: isSelected
                  ? (isDark
                      ? AppColors.borderStrong
                      : AppColors.borderStrongLight)
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: inkPrimary,
                        fontFamily: AppTextStyles.latinFontFamily,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (samples.isNotEmpty) ...[
                      const Gap(AppDimensions.spacingXxs),
                      Text(
                        samples.join(' · '),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: inkMuted,
                          fontFamily: AppTextStyles.latinFontFamily,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: inkPrimary,
                  size: AppDimensions.iconSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
