import 'package:pdf/pdf.dart';

/// Khazna v3 — Lapis Lux palette for tier-1 private-banking PDF output.
///
/// Print design uses Lapis gradient fills on structural anchors and pearl-tinted
/// table striping on an uninterrupted Bone/white canvas. Onyx is body text only;
/// semantic red/green appear exclusively on monetary values.
abstract final class PdfBrandColors {
  // Lapis Lux — gradient components
  static const lapisPrimary = PdfColor.fromInt(0xFF0356C5);
  static const lapisGradientStart = PdfColor.fromInt(0xFF021D4D);
  static const lapisGradientEnd = PdfColor.fromInt(0xFF2D78F0);
  static const PdfColor lapisBorder = lapisPrimary;
  static const PdfColor lapisBorderSoft = PdfColor.fromInt(0xFFBBD0F4);

  // Monochrome — ink and neutral surfaces
  static const inkPrimary = PdfColor.fromInt(0xFF0A0A0C);
  static const inkSecondary = PdfColor.fromInt(0xFF5C5C62);
  static const inkOnLapis = PdfColor.fromInt(0xFFFFFFFF);
  static const pearlCanvas = PdfColor.fromInt(0xFFFAFBFD);
  static const pearlStripe = PdfColor.fromInt(0xFFF5F7FA);
  static const cardSurfaceTop = PdfColor.fromInt(0xFFFFFFFF);
  static const cardSurfaceBottom = PdfColor.fromInt(0xFFF5F7FA);
  static const borderSubtle = PdfColor.fromInt(0xFFE5E2DC);
  static const tableGridDivider = PdfColor.fromInt(0xFFEBE8E2);

  /// ~8% opacity Lapis — card elevation shadow.
  static const cardShadow = PdfColor.fromInt(0x140356C5);

  // Semantic — debt (عليه) / payment (له)
  static const debt = PdfColor.fromInt(0xFFC8281C);
  static const payment = PdfColor.fromInt(0xFF15803D);
}
