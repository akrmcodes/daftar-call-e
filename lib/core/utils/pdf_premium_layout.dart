import 'package:daftar/core/utils/pdf_colors.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared premium layout primitives for Daftar PDF reports.
abstract final class PdfPremiumLayout {
  /// Swiss-grid hairline — footer rules and intra-card separators.
  static const double hairline = 0.2;

  /// Inner table grid lines.
  static const double gridLine = 0.35;

  /// Table frame and card outline weight.
  static const double frameLine = 0.35;

  /// Vertical rhythm between currency sections.
  static const double sectionGap = 36;

  /// Air above summary / totals cards after data tables.
  static const double summaryTopBreathing = 18;

  /// Air below summary cards before the next section.
  static const double summaryBottomBreathing = 10;

  static const pw.LinearGradient brandLapisGradient = pw.LinearGradient(
    colors: <PdfColor>[
      PdfBrandColors.lapisGradientStart,
      PdfBrandColors.lapisGradientEnd,
    ],
  );

  static const pw.LinearGradient cardPearlGradient = pw.LinearGradient(
    begin: pw.Alignment.topCenter,
    end: pw.Alignment.bottomCenter,
    colors: <PdfColor>[
      PdfBrandColors.cardSurfaceTop,
      PdfBrandColors.cardSurfaceBottom,
    ],
  );

  static const pw.TableBorder dataTableBorder = pw.TableBorder(
    horizontalInside: pw.BorderSide(
      color: PdfBrandColors.tableGridDivider,
      width: gridLine,
    ),
    verticalInside: pw.BorderSide(
      color: PdfBrandColors.tableGridDivider,
      width: hairline,
    ),
    top: pw.BorderSide(color: PdfBrandColors.lapisBorderSoft, width: frameLine),
    bottom: pw.BorderSide(color: PdfBrandColors.lapisBorderSoft, width: frameLine),
    left: pw.BorderSide(color: PdfBrandColors.tableGridDivider, width: gridLine),
    right: pw.BorderSide(color: PdfBrandColors.tableGridDivider, width: gridLine),
  );

  static const pw.BoxDecoration _accentStripDecoration = pw.BoxDecoration(
    gradient: brandLapisGradient,
    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
  );

  /// 5dp top accent strip with deep-to-luminous Lapis gradient.
  static pw.BoxDecoration accentStripDecoration() => _accentStripDecoration;

  /// Repeating table header row fill.
  static pw.BoxDecoration headerRowDecoration() {
    return const pw.BoxDecoration(gradient: brandLapisGradient);
  }

  /// Per-currency section badge.
  static pw.BoxDecoration currencyBadgeDecoration() {
    return pw.BoxDecoration(
      gradient: brandLapisGradient,
      borderRadius: pw.BorderRadius.circular(6),
    );
  }

  /// Statement / ledger title card beneath the header.
  static pw.BoxDecoration titleCardDecoration() {
    return pw.BoxDecoration(
      gradient: cardPearlGradient,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfBrandColors.lapisBorderSoft, width: frameLine),
      boxShadow: const <pw.BoxShadow>[
        pw.BoxShadow(
          color: PdfBrandColors.cardShadow,
          blurRadius: 8,
          offset: PdfPoint(0, 2),
        ),
      ],
    );
  }

  /// Totals / net-balance summary card at the foot of each currency section.
  static pw.BoxDecoration summaryCardDecoration() {
    return pw.BoxDecoration(
      gradient: cardPearlGradient,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: PdfBrandColors.lapisBorderSoft, width: frameLine),
      boxShadow: const <pw.BoxShadow>[
        pw.BoxShadow(
          color: PdfBrandColors.cardShadow,
          blurRadius: 8,
          offset: PdfPoint(0, 2),
        ),
      ],
    );
  }

  /// Hairline rule for footers and summary-card separators.
  static pw.Widget hairlineDivider({PdfColor color = PdfBrandColors.borderSubtle}) {
    return pw.Divider(color: color, thickness: hairline);
  }

  /// Summary card interior padding — generous vertical air for figures.
  static const pw.EdgeInsets summaryCardPadding = pw.EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 20,
  );
}
