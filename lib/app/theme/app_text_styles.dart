import 'package:flutter/material.dart';

/// Khazna v3 — Daftar typography.
///
/// Bilingual by birth:
///   * **Noto Kufi Arabic** — all Arabic UI text (headings, body, labels).
///   * **Inter** — all Latin text and **all numerals**.
///
/// All numeral styles MANDATE `FontFeature.tabularFigures()` +
/// `FontFeature.liningFigures()` so monetary amounts align vertically in
/// lists. This is the single visual cue that separates "fintech" from
/// "consumer app." See `docs/design_system.md` §3.3.
///
/// Fonts are bundled in `assets/fonts/` — no runtime downloads.
abstract final class AppTextStyles {
  static const String arabicFontFamily = 'NotoKufiArabic';
  static const String latinFontFamily = 'Inter';

  /// `FontFeature` set applied to every Inter numeral style.
  static const List<FontFeature> _numeralFeatures = [
    FontFeature.tabularFigures(),
    FontFeature.liningFigures(),
  ];

  // ==========================================================================
  // ARABIC SCALE — Noto Kufi Arabic
  // ==========================================================================

  static const TextStyle displayLarge = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: arabicFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.5,
  );

  // ==========================================================================
  // NUMERAL SCALE — Inter, tabular figures MANDATORY
  // ==========================================================================

  static const TextStyle amountHero = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.8,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle amountLarge = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle amountMedium = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle amountSmall = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle amountMicro = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle numeralInput = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 4,
    fontFeatures: _numeralFeatures,
  );

  static const TextStyle numeralCaption = TextStyle(
    fontFamily: latinFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.3,
    fontFeatures: _numeralFeatures,
  );
}
