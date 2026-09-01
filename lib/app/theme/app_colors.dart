import 'package:flutter/material.dart';

/// Khazna v3 — Lapis Lux color tokens.
///
/// Three citizens own the entire palette:
///   * **Monochrome** (Onyx / Bone Parchment) — canvas, surfaces, ink. ~95%.
///   * **Luminous Lapis** (`lapis400` = #0356C5) — light, never paint. ~3%.
///   * **Semantic** (debt / payment / warning / info) — only where money lives. ~2%.
///
/// Any color outside this triad is categorically banned. See
/// `docs/design_system.md` §2 for the full doctrine.
abstract final class AppColors {
  // ==========================================================================
  // ONYX — Monochrome scale (Dark, default)
  // ==========================================================================

  static const Color surface0 = Color(0xFF000000);
  static const Color surface1 = Color(0xFF0A0A0A);
  static const Color surface2 = Color(0xFF121214);
  static const Color surface3 = Color(0xFF18181C);
  static const Color surface4 = Color(0xFF1F1F24);
  static const Color surface5 = Color(0xFF26262C);
  static const Color surface6 = Color(0xFF33333A);

  static const Color inkPrimary = Color(0xFFF5F5F5);
  static const Color inkSecondary = Color(0xFFA8A8AE);
  static const Color inkMuted = Color(0xFF6E6E76);
  static const Color inkDisabled = Color(0xFF3A3A40);

  static const Color borderSubtle = Color(0xFF26262C);
  static const Color borderStrong = Color(0xFF3A3A40);

  static const Color scrim = Color(0xC7000000);
  static const Color glassFill = Color(0x9E121214);
  static const Color glassBorder = Color(0x0FFFFFFF);
  static const Color innerTopHighlight = Color(0x0AFFFFFF);

  /// Razor-bright specular line on glass bevels (dark canvas).
  static const Color specularRazorDark = Color(0x35FFFFFF);

  /// Razor-bright specular line on glass bevels (light canvas).
  static const Color specularRazorLight = Color(0x26FFFFFF);

  // ==========================================================================
  // OPACITY — design_system §2.7 named alphas (no arbitrary withOpacity)
  // ==========================================================================

  static const double alphaHairline = 0.04;
  static const double alphaWhisper = 0.06;
  static const double alphaSubtle = 0.08;
  static const double alphaSoft = 0.12;
  static const double alphaMedium = 0.24;
  static const double alphaStrong = 0.48;
  static const double alphaScrim = 0.78;
  static const double alphaOpaque = 1;

  // ==========================================================================
  // BONE PARCHMENT — Monochrome scale (Light)
  // ==========================================================================

  static const Color surface0Light = Color(0xFFF8F7F4);
  static const Color surface1Light = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFF2F0EC);
  static const Color surface3Light = Color(0xFFE8E5DE);
  static const Color surface4Light = Color(0xFFDAD6CB);

  static const Color inkPrimaryLight = Color(0xFF0A0A0C);
  static const Color inkSecondaryLight = Color(0xFF5C5C62);
  static const Color inkMutedLight = Color(0xFF9A9A9F);
  static const Color inkDisabledLight = Color(0xFFC2C2C7);

  static const Color borderSubtleLight = Color(0xFFE5E2DC);
  static const Color borderStrongLight = Color(0xFFC7C2B6);

  static const Color scrimLight = Color(0x85140C0C);
  static const Color glassFillLight = Color(0xB8FFFFFF);
  static const Color glassBorderLight = Color(0x0F000000);

  // ==========================================================================
  // LUMINOUS LAPIS — The single brand color (light, never paint)
  // ==========================================================================

  static const Color lapis50 = Color(0xFFE6EEFB);
  static const Color lapis100 = Color(0xFFBBD0F4);
  static const Color lapis200 = Color(0xFF86A8EA);
  static const Color lapis300 = Color(0xFF4A7DDC);
  static const Color lapis400 = Color(0xFF0356C5);
  static const Color lapis500 = Color(0xFF0247A8);
  static const Color lapis600 = Color(0xFF02398A);
  static const Color lapis700 = Color(0xFF022B6B);
  static const Color lapis800 = Color(0xFF021D4D);
  static const Color lapis900 = Color(0xFF02060E);

  static const Color lapisLumen = Color(0xFF2D78F0);

  // ==========================================================================
  // SEMANTIC — The only other chromatic colors
  // ==========================================================================

  static const Color debt = Color(0xFFFF5757);
  static const Color debtContainer = Color(0xFF2E0E0E);
  static const Color onDebt = Color(0xFFFFEBEB);

  static const Color debtLight = Color(0xFFC8281C);
  static const Color debtContainerLight = Color(0xFFFFEBED);
  static const Color onDebtLight = Color(0xFF5C0A05);

  static const Color payment = Color(0xFF4ADE80);
  static const Color paymentContainer = Color(0xFF0B2E1A);
  static const Color onPayment = Color(0xFFE8FCEF);

  static const Color paymentLight = Color(0xFF15803D);
  static const Color paymentContainerLight = Color(0xFFE6F7EC);
  static const Color onPaymentLight = Color(0xFF0A3D1E);

  static const Color warning = Color(0xFFF5A623);
  static const Color warningContainer = Color(0xFF2E2410);
  static const Color onWarning = Color(0xFFFFF3DC);

  static const Color warningLight = Color(0xFFB45309);
  static const Color warningContainerLight = Color(0xFFFFF6E5);
  static const Color onWarningLight = Color(0xFF5C3300);

  static const Color info = lapis400;
  static const Color infoContainer = lapis800;
  static const Color onInfo = lapis50;

  static const Color infoLight = lapis500;
  static const Color infoContainerLight = lapis50;
  static const Color onInfoLight = lapis800;

  static const Color success = payment;
  static const Color successContainer = paymentContainer;
  static const Color onSuccess = onPayment;

  static const Color error = debt;
  static const Color errorContainer = debtContainer;
  static const Color onError = onDebt;

  static const Color errorLight = debtLight;
  static const Color errorContainerLight = debtContainerLight;
  static const Color onErrorLight = onDebtLight;

  // ==========================================================================
  // SHIMMER (skeleton loading) — strictly monochrome
  // ==========================================================================

  static const Color shimmerBase = surface3;
  static const Color shimmerHighlight = surface5;
  static const Color shimmerBaseLight = surface2Light;
  static const Color shimmerHighlightLight = surface3Light;

  // ==========================================================================
  // AVATAR SET — muted, uniform-saturation (never competes with lapis or semantic)
  // ==========================================================================

  static const List<Color> avatarColors = [
    Color(0xFF5C6BC0),
    Color(0xFF4A9D94),
    Color(0xFFC95757),
    Color(0xFF8E64A8),
    Color(0xFF5586C2),
    Color(0xFFC68E4A),
    Color(0xFF6FA973),
    Color(0xFFC97091),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  // ==========================================================================
  // BACKWARD-COMPAT ALIASES — DEPRECATED
  //
  // These names exist so the legacy UI compiles during the Khazna v2 → v3
  // migration. They resolve to the closest v3 token (typically a monochrome
  // surface or lapis variant). Any reference to these MUST be migrated to the
  // canonical v3 tokens above before the next major release.
  // ==========================================================================

  @Deprecated('Khazna v3: use surface0')
  static const Color darkBackground = surface0;
  @Deprecated('Khazna v3: use surface2')
  static const Color darkSurface = surface2;
  @Deprecated('Khazna v3: use surface3')
  static const Color darkSurfaceVariant = surface3;
  @Deprecated('Khazna v3: use surface5')
  static const Color darkSurfaceTertiary = surface5;
  @Deprecated('Khazna v3: use inkPrimary')
  static const Color darkOnSurface = inkPrimary;
  @Deprecated('Khazna v3: use inkSecondary')
  static const Color darkOnSurfaceVariant = inkSecondary;
  @Deprecated('Khazna v3: use inkMuted')
  static const Color darkOnSurfaceMuted = inkMuted;
  @Deprecated('Khazna v3: brand is lapis400; CTAs use surface+glow, not fill')
  static const Color darkPrimary = lapis400;
  @Deprecated('Khazna v3: use lapis800 (info container)')
  static const Color darkPrimaryContainer = lapis800;
  @Deprecated('Khazna v3: white on lapis fills, inkPrimary on monochrome')
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  @Deprecated('Khazna v3: accent consolidated into lapis brand')
  static const Color darkAccent = lapis400;
  @Deprecated('Khazna v3: use lapis800')
  static const Color darkAccentContainer = lapis800;

  @Deprecated('Khazna v3: use surface0Light')
  static const Color lightBackground = surface0Light;
  @Deprecated('Khazna v3: use surface1Light')
  static const Color lightSurface = surface1Light;
  @Deprecated('Khazna v3: use surface2Light')
  static const Color lightSurfaceVariant = surface2Light;
  @Deprecated('Khazna v3: use surface3Light')
  static const Color lightSurfaceTertiary = surface3Light;
  @Deprecated('Khazna v3: use inkPrimaryLight')
  static const Color lightOnSurface = inkPrimaryLight;
  @Deprecated('Khazna v3: use inkSecondaryLight')
  static const Color lightOnSurfaceVariant = inkSecondaryLight;
  @Deprecated('Khazna v3: use inkMutedLight')
  static const Color lightOnSurfaceMuted = inkMutedLight;
  @Deprecated('Khazna v3: brand is lapis500 (light); CTAs use surface+glow')
  static const Color lightPrimary = lapis500;
  @Deprecated('Khazna v3: use lapis50')
  static const Color lightPrimaryContainer = lapis50;
  @Deprecated('Khazna v3: white on lapis fills')
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  @Deprecated('Khazna v3: accent consolidated into lapis brand')
  static const Color lightAccent = lapis500;
  @Deprecated('Khazna v3: use lapis50')
  static const Color lightAccentContainer = lapis50;

  @Deprecated('Khazna v3: use borderSubtle')
  static const Color dividerDark = borderSubtle;
  @Deprecated('Khazna v3: use borderSubtleLight')
  static const Color dividerLight = borderSubtleLight;
}
