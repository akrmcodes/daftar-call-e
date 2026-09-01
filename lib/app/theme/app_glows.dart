import 'package:flutter/widgets.dart';

/// Khazna v3 — Luminous Lapis glow tokens & light-mode paired shadows.
///
/// Lapis is light, not paint. Every BoxShadow color in this file derives from
/// `lapis400` (#0356C5) at the precise alpha specified in
/// `docs/design_system.md` §2.5.
///
/// Alpha conversions:
///   0.20 → 0x33   0.28 → 0x47   0.36 → 0x5C
///   0.44 → 0x70   0.72 → 0xB8
abstract final class AppGlows {
  // ==========================================================================
  // LAPIS HALOS — single BoxShadow constants
  // ==========================================================================

  static const BoxShadow glowXs = BoxShadow(
    color: Color(0x330356C5),
    blurRadius: 4,
  );

  static const BoxShadow glowSm = BoxShadow(
    color: Color(0x470356C5),
    blurRadius: 8,
  );

  static const BoxShadow glowMd = BoxShadow(
    color: Color(0x5C0356C5),
    blurRadius: 16,
  );

  static const BoxShadow glowLg = BoxShadow(
    color: Color(0x700356C5),
    blurRadius: 24,
  );

  static const BoxShadow glowXl = BoxShadow(
    color: Color(0x5C0356C5),
    blurRadius: 48,
  );

  // Khazna Float — deep ambient shadow for floating cards on dark.
  // Base color is lapis900 (#02060E) at 0.72 alpha.
  static const BoxShadow glowAmbient = BoxShadow(
    color: Color(0xB802060E),
    blurRadius: 32,
    offset: Offset(0, 8),
  );

  // ==========================================================================
  // LIST WRAPPERS — for direct use in BoxDecoration.boxShadow
  // ==========================================================================

  static const List<BoxShadow> haloXs = [glowXs];
  static const List<BoxShadow> haloSm = [glowSm];
  static const List<BoxShadow> haloMd = [glowMd];
  static const List<BoxShadow> haloLg = [glowLg];
  static const List<BoxShadow> haloXl = [glowXl];

  /// Micro edge lift for scroll-path list tiles (blur ≤ 2, monochrome only).
  static const List<BoxShadow> listTileEdge = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Dark-mode floating card ambient shadow.
  /// Pair with a 0.5px borderSubtle outline + a top-edge inner highlight
  /// (`AppColors.innerTopHighlight`) for the full Khazna Float effect.
  static const List<BoxShadow> khazaFloat = [glowAmbient];

  // Primary CTA state-machine halos.
  static const List<BoxShadow> ctaRest = [glowMd];
  static const List<BoxShadow> ctaPressed = [glowSm];
  static const List<BoxShadow> ctaFocused = [glowLg];

  // Premium tier card halos (§16).
  static const List<BoxShadow> premiumPro = [glowSm];
  static const List<BoxShadow> premiumProPlus = [glowMd];

  // Hero brand-mark glow — splash, lock screen, onboarding.
  static const List<BoxShadow> heroBrand = [glowXl];

  /// Studio illumination — emissive point light behind a hero (Closing Agent).
  /// Lapis as light, not paint: BoxShadow emission only. Pair with [glowXl]
  /// for falloff. Not a CTA halo — ambient Salāsa depth.
  static const BoxShadow glowWell = BoxShadow(
    color: Color(0x290356C5),
    blurRadius: 96,
    spreadRadius: 8,
  );

  /// Dark-mode studio well (core + falloff).
  static const List<BoxShadow> studioWellDark = [glowWell, glowXl];

  /// Light-mode studio well — quieter alpha (~0.06).
  static const List<BoxShadow> studioWellLight = [
    BoxShadow(
      color: Color(0x0F0356C5),
      blurRadius: 96,
      spreadRadius: 8,
    ),
    BoxShadow(
      color: Color(0x0A0356C5),
      blurRadius: 48,
    ),
  ];

  /// Floor bounce behind a floating dock (dark only).
  static const BoxShadow glowWellFloor = BoxShadow(
    color: Color(0x140356C5),
    blurRadius: 64,
    spreadRadius: 4,
    offset: Offset(0, 12),
  );

  // ==========================================================================
  // LIGHT-MODE PAIRED SHADOWS — no lapis at rest
  //
  // Alpha conversions:
  //   0.03 → 0x08   0.04 → 0x0A   0.06 → 0x0F
  //   0.08 → 0x14   0.10 → 0x1A   0.14 → 0x24
  // ==========================================================================

  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowFloat = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowElevated = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowDeep = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 64,
      offset: Offset(0, 24),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}
