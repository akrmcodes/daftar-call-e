import 'package:daftar/app/theme/app_text_styles.dart';
import 'package:daftar/core/constants/db_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a currency display mark — official SVG for SAR, text otherwise.
///
/// Saudi Riyal uses the SAMA official symbol asset
/// (`assets/icons/saudi_riyal_symbol.svg`), tinted to [color]. Never mirror.
class CurrencySymbolMark extends StatelessWidget {
  const CurrencySymbolMark({
    required this.currencyCode,
    required this.symbol,
    required this.color,
    super.key,
    this.height = 14,
  });

  final String currencyCode;
  final String symbol;
  final Color color;

  /// Glyph height in logical pixels. Width follows official SAR aspect ratio.
  final double height;

  /// Official SAMA Saudi Riyal Symbol (SVG).
  static const String saudiRiyalAssetPath =
      'assets/icons/saudi_riyal_symbol.svg';

  /// Unicode SAUDI RIYAL SIGN (U+20C1). Stored in DB; UI prefers the SVG.
  static const String saudiRiyalSign = '\u20C1';

  /// Official viewBox width / height from SAMA SVG (1124.14 / 1256.39).
  static const double _sarAspectRatio = 1124.14 / 1256.39;

  bool get _isSaudiRiyal =>
      currencyCode.trim().toUpperCase() == DbConstants.currencySar;

  @override
  Widget build(BuildContext context) {
    if (_isSaudiRiyal) {
      final width = height * _sarAspectRatio;
      return Semantics(
        label: 'Saudi Riyal',
        image: true,
        excludeSemantics: true,
        child: SvgPicture.asset(
          saudiRiyalAssetPath,
          width: width,
          height: height,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          excludeFromSemantics: true,
        ),
      );
    }

    return Text(
      symbol,
      style: AppTextStyles.labelMedium.copyWith(
        color: color,
        fontFamily: AppTextStyles.latinFontFamily,
        fontSize: height,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
