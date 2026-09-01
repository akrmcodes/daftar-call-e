import 'package:equatable/equatable.dart';

/// Integer money totals for one currency on a merchant `localDay`.
class ClosingDayCurrencyTotals extends Equatable {
  /// Creates currency totals.
  const ClosingDayCurrencyTotals({
    required this.currencyCode,
    required this.debtMinor,
    required this.paymentMinor,
  });

  /// ISO 4217 code.
  final String currencyCode;

  /// Sum of debt amounts (always ≥ 0) in minor units.
  final int debtMinor;

  /// Sum of payment amounts (always ≥ 0) in minor units.
  final int paymentMinor;

  @override
  List<Object?> get props => [currencyCode, debtMinor, paymentMinor];
}

/// Drift snapshot of today's books (Appendix J.4). Journal is not SoT.
class ClosingDaySummary extends Equatable {
  /// Creates a day summary.
  const ClosingDaySummary({
    required this.localDay,
    required this.debtCount,
    required this.paymentCount,
    required this.totals,
  });

  /// Empty successful close for [localDay].
  factory ClosingDaySummary.empty(String localDay) {
    return ClosingDaySummary(
      localDay: localDay,
      debtCount: 0,
      paymentCount: 0,
      totals: const [],
    );
  }

  /// Merchant calendar day `YYYY-MM-DD`.
  final String localDay;

  /// Number of non-deleted, non-archived debt rows created that day.
  final int debtCount;

  /// Number of non-deleted, non-archived payment rows created that day.
  final int paymentCount;

  /// Per-currency integer totals, sorted by currency code.
  final List<ClosingDayCurrencyTotals> totals;

  @override
  List<Object?> get props => [localDay, debtCount, paymentCount, totals];
}
