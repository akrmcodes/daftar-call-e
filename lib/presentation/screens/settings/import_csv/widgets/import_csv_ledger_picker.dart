import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/daftar_card.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Target-ledger selector for CSV import — chips for few ledgers, sheet for many.
class ImportCsvLedgerPicker extends StatelessWidget {
  const ImportCsvLedgerPicker({
    required this.ledgers,
    required this.selectedLedgerId,
    required this.onSelected,
    super.key,
  });

  final List<Ledger> ledgers;
  final String? selectedLedgerId;
  final ValueChanged<String> onSelected;

  Ledger? get _selectedLedger {
    if (selectedLedgerId == null) {
      return null;
    }
    for (final ledger in ledgers) {
      if (ledger.id == selectedLedgerId) {
        return ledger;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;
    final selected = _selectedLedger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.csvImportTargetLedgerLabel,
          style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
        ),
        const Gap(AppDimensions.spacingXs),
        Text(
          l10n.csvImportTargetLedgerHint,
          style: AppTextStyles.bodySmall.copyWith(color: inkMuted),
        ),
        const Gap(AppDimensions.spacingMd),
        if (ledgers.length <= 3)
          _InlineLedgerChips(
            ledgers: ledgers,
            selectedLedgerId: selectedLedgerId,
            onSelected: onSelected,
          )
        else
          DaftarCard(
            variant: selected == null
                ? DaftarCardVariant.hero
                : DaftarCardVariant.standard,
            onTap: () => _openLedgerSheet(context),
            child: _LedgerRow(
              ledger: selected,
              placeholder: l10n.csvImportNoLedgerSelected,
              showChevron: true,
            ),
          ),
      ],
    );
  }

  Future<void> _openLedgerSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await HapticService.light();
    if (!context.mounted) {
      return;
    }

    final picked = await AppBottomSheet.show<String>(
      context,
      title: l10n.csvImportChooseLedgerTitle,
      subtitle: l10n.csvImportTargetLedgerHint,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ledgers.length,
        separatorBuilder: (context, index) =>
            const Gap(AppDimensions.spacingXs),
        itemBuilder: (context, index) {
          final ledger = ledgers[index];
          final isSelected = ledger.id == selectedLedgerId;
          return _LedgerSheetTile(
            ledger: ledger,
            isSelected: isSelected,
            onTap: () => Navigator.of(context).pop(ledger.id),
          );
        },
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }
}

class _InlineLedgerChips extends StatelessWidget {
  const _InlineLedgerChips({
    required this.ledgers,
    required this.selectedLedgerId,
    required this.onSelected,
  });

  final List<Ledger> ledgers;
  final String? selectedLedgerId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ledgers.length,
        separatorBuilder: (context, index) =>
            const Gap(AppDimensions.spacingSm),
        itemBuilder: (context, index) {
          final ledger = ledgers[index];
          return _LedgerChip(
            ledger: ledger,
            selected: ledger.id == selectedLedgerId,
            onSelected: () {
              unawaited(HapticService.selection());
              onSelected(ledger.id);
            },
          );
        },
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.ledger,
    required this.placeholder,
    required this.showChevron,
  });

  final Ledger? ledger;
  final String placeholder;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkPrimary =
        isDark ? AppColors.inkPrimary : AppColors.inkPrimaryLight;
    final inkMuted = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    if (ledger == null) {
      return Row(
        children: [
          Icon(Icons.menu_book_outlined, color: inkMuted),
          const Gap(AppDimensions.spacingMd),
          Expanded(
            child: Text(
              placeholder,
              style: AppTextStyles.bodyMedium.copyWith(color: inkMuted),
            ),
          ),
          if (showChevron) Icon(Icons.unfold_more_rounded, color: inkMuted),
        ],
      );
    }

    final accent = _parseLedgerHexColor(ledger!.color);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const Gap(AppDimensions.spacingMd),
        Expanded(
          child: Text(
            ledger!.name,
            style: AppTextStyles.titleSmall.copyWith(color: inkPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showChevron) Icon(Icons.unfold_more_rounded, color: inkMuted),
      ],
    );
  }
}

class _LedgerChip extends StatelessWidget {
  const _LedgerChip({
    required this.ledger,
    required this.selected,
    required this.onSelected,
  });

  final Ledger ledger;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _parseLedgerHexColor(ledger.color);
    final fill = selected
        ? (isDark ? AppColors.surface3 : AppColors.surface1Light)
        : (isDark ? AppColors.surface4 : AppColors.surface2Light);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
            border: Border.all(
              color: selected
                  ? (isDark
                      ? AppColors.borderStrong
                      : AppColors.borderStrongLight)
                  : (isDark
                      ? AppColors.borderSubtle
                      : AppColors.borderSubtleLight),
            ),
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const Gap(AppDimensions.spacingSm),
              Text(
                ledger.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? (isDark
                          ? AppColors.inkPrimary
                          : AppColors.inkPrimaryLight)
                      : (isDark
                          ? AppColors.inkSecondary
                          : AppColors.inkSecondaryLight),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerSheetTile extends StatelessWidget {
  const _LedgerSheetTile({
    required this.ledger,
    required this.isSelected,
    required this.onTap,
  });

  final Ledger ledger;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          child: _LedgerRow(
            ledger: ledger,
            placeholder: '',
            showChevron: isSelected,
          ),
        ),
      ),
    );
  }
}

Color _parseLedgerHexColor(String value) {
  var hex = value.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return AppColors.inkMuted;
  }
  return Color(parsed);
}
