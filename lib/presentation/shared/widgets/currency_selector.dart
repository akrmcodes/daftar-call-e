import 'dart:math' as math;

import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/presentation/shared/widgets/app_bottom_sheet.dart';
import 'package:daftar/presentation/shared/widgets/currency_symbol_mark.dart';
import 'package:daftar/presentation/shared/widgets/daftar_close_icon_button.dart';
import 'package:flutter/material.dart';

/// How the currency selector should be presented.
enum CurrencySelectorDisplayMode {
  chips,
  picker,
}

/// Selector for choosing an active currency.
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({
    required this.currencies,
    required this.selectedCurrencyCode,
    required this.onChanged,
    super.key,
    this.displayMode = CurrencySelectorDisplayMode.chips,
    this.label,
    this.helperText,
    this.sheetTitle,
    this.sheetSubtitle,
    this.enabled = true,
  });

  final List<Currency> currencies;
  final String selectedCurrencyCode;
  final ValueChanged<Currency> onChanged;
  final CurrencySelectorDisplayMode displayMode;
  final String? label;
  final String? helperText;
  final String? sheetTitle;
  final String? sheetSubtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = _selectedCurrency;
    final isDark = context.theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.titleSmall.copyWith(
              color: titleColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        if (displayMode == CurrencySelectorDisplayMode.chips)
          _CurrencyChipStrip(
            currencies: currencies,
            selectedCurrencyCode: selectedCurrencyCode,
            enabled: enabled,
            onChanged: onChanged,
          )
        else
          _CurrencyPickerField(
            currency: selectedCurrency,
            enabled: enabled,
            onTap: () => _showPicker(context),
          ),
        if (helperText != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            helperText!,
            style: AppTextStyles.bodySmall.copyWith(
              color: mutedColor,
            ),
          ),
        ],
      ],
    );
  }

  Currency get _selectedCurrency {
    for (final currency in currencies) {
      if (currency.code == selectedCurrencyCode) {
        return currency;
      }
    }

    return currencies.first;
  }

  Future<void> _showPicker(BuildContext context) async {
    if (!enabled || currencies.isEmpty) {
      return;
    }

    final selected = await AppBottomSheet.show<Currency>(
      context,
      title: sheetTitle ?? label,
      subtitle: sheetSubtitle,
      scrollable: false,
      trailing: DaftarCloseIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: _CurrencyPickerList(
        currencies: currencies,
        selectedCurrencyCode: selectedCurrencyCode,
      ),
    );

    if (selected != null) {
      onChanged(selected);
    }
  }
}

class _CurrencyChipStrip extends StatelessWidget {
  const _CurrencyChipStrip({
    required this.currencies,
    required this.selectedCurrencyCode,
    required this.onChanged,
    required this.enabled,
  });

  final List<Currency> currencies;
  final String selectedCurrencyCode;
  final ValueChanged<Currency> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final mutedColor = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;

    if (currencies.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleColumns = math.max(1, math.min(4, currencies.length));
        final chipWidth =
            (constraints.maxWidth -
                (AppDimensions.spacingSm * (visibleColumns - 1))) /
            visibleColumns;

        return Wrap(
          spacing: AppDimensions.spacingSm,
          runSpacing: AppDimensions.spacingSm,
          children: [
            for (final currency in currencies)
              SizedBox(
                width: chipWidth,
                child: _CurrencyChip(
                  currency: currency,
                  selected: currency.code == selectedCurrencyCode,
                  enabled: enabled,
                  borderColor: borderColor,
                  mutedColor: mutedColor,
                  onTap: () => onChanged(currency),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.currency,
    required this.selected,
    required this.enabled,
    required this.borderColor,
    required this.mutedColor,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final bool enabled;
  final Color borderColor;
  final Color mutedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.lapis400
        : AppColors.lapis500;
    final primaryContainer = isDark
        ? AppColors.lapis800
        : AppColors.lapis50;
    final onPrimary = isDark
        ? Colors.white
        : Colors.white;
    final surfaceColor = isDark
        ? AppColors.surface3
        : AppColors.surface2Light;
    final codeColor = selected ? primaryColor : mutedColor;
    final symbolBackgroundColor = selected
        ? primaryColor.withValues(alpha: 0.16)
        : primaryColor.withValues(alpha: 0.10);
    final symbolColor = selected ? onPrimary : primaryColor;
    final displayName = context.isRtl ? currency.nameAr : currency.nameEn;

    return Semantics(
      button: true,
      selected: selected,
      label: '${currency.code}, $displayName',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.98,
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: AppDimensions.animationFast,
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingSm,
                vertical: 6,
              ),
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTapTarget,
              ),
              decoration: BoxDecoration(
                color: selected ? primaryContainer : surfaceColor,
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusCircular,
                ),
                border: Border.all(
                  color: selected
                      ? primaryColor.withValues(alpha: 0.24)
                      : borderColor,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppDimensions.animationFast,
                    curve: Curves.easeOutCubic,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: symbolBackgroundColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: CurrencySymbolMark(
                      currencyCode: currency.code,
                      symbol: currency.symbol,
                      color: symbolColor,
                      height: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      currency.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: codeColor,
                        fontFamily: AppTextStyles.latinFontFamily,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyPickerField extends StatelessWidget {
  const _CurrencyPickerField({
    required this.currency,
    required this.enabled,
    required this.onTap,
  });

  final Currency currency;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.surface5
        : AppColors.surface3Light;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final titleColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkMuted
        : AppColors.inkMutedLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: AnimatedContainer(
          duration: AppDimensions.animationFast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
            vertical: AppDimensions.spacingSm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: titleColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: CurrencySymbolMark(
                  currencyCode: currency.code,
                  symbol: currency.symbol,
                  color: titleColor,
                  height: 12,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.code,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: titleColor,
                        fontFamily: AppTextStyles.latinFontFamily,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      context.isRtl ? currency.nameAr : currency.nameEn,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                context.isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: mutedColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyPickerList extends StatelessWidget {
  const _CurrencyPickerList({
    required this.currencies,
    required this.selectedCurrencyCode,
  });

  final List<Currency> currencies;
  final String selectedCurrencyCode;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? AppColors.inkPrimary
        : AppColors.inkPrimaryLight;
    final mutedColor = isDark
        ? AppColors.inkSecondary
        : AppColors.inkSecondaryLight;
    final borderColor = isDark ? AppColors.borderSubtle : AppColors.borderSubtleLight;
    final primaryColor = isDark
        ? AppColors.lapis400
        : AppColors.lapis500;
    final primaryContainer = isDark
        ? AppColors.lapis800
        : AppColors.lapis50;

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
      itemCount: currencies.length,
      separatorBuilder: (context, _) => Divider(
        color: borderColor,
        height: AppDimensions.spacingXl,
      ),
      itemBuilder: (context, index) {
        final currency = currencies[index];
        final selected = currency.code == selectedCurrencyCode;

        return InkWell(
          onTap: () => Navigator.of(context).pop(currency),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: AnimatedContainer(
            duration: AppDimensions.animationFast,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: AppDimensions.spacingMd,
            ),
            decoration: BoxDecoration(
              color: selected ? primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: selected
                    ? primaryColor.withValues(alpha: 0.2)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: AppDimensions.avatarSmall,
                  height: AppDimensions.avatarSmall,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(
                      alpha: selected ? 0.16 : 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: CurrencySymbolMark(
                    currencyCode: currency.code,
                    symbol: currency.symbol,
                    color: primaryColor,
                    height: 16,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency.code,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: titleColor,
                          fontFamily: AppTextStyles.latinFontFamily,
                        ),
                      ),
                      Text(
                        context.isRtl ? currency.nameAr : currency.nameEn,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: primaryColor,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
