import 'package:daftar/app/theme/app_colors.dart';
import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/extensions/context_extensions.dart';
import 'package:daftar/domain/entities/currency.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:daftar/presentation/shared/widgets/currency_symbol_mark.dart';
import 'package:flutter/material.dart';

/// Non-interactive currency label for amount fields when multi-currency is off.
class ReadOnlyCurrencySuffix extends StatelessWidget {
  const ReadOnlyCurrencySuffix({
    required this.currencyCode,
    required this.currencies,
    super.key,
  });

  final String currencyCode;
  final List<Currency> currencies;

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    final symbol = symbolForCurrencyCode(currencyCode, currencies);
    final color = isDark ? AppColors.inkMuted : AppColors.inkMutedLight;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        end: AppDimensions.spacingMd,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: CurrencySymbolMark(
          currencyCode: currencyCode,
          symbol: symbol,
          color: color,
        ),
      ),
    );
  }
}
