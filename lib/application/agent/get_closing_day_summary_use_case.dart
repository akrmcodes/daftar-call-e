import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:fpdart/fpdart.dart';

/// Aggregates live Drift rows created on the merchant `localDay` (Appendix J.4).
///
/// Journal is not the source of truth. Empty day is success with zeros.
class GetClosingDaySummaryUseCase {
  /// Creates the use case.
  const GetClosingDaySummaryUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Returns counts and integer per-currency totals for [localDay].
  Future<Either<Failure, ClosingDaySummary>> execute({
    String? localDay,
    DateTime? now,
  }) async {
    final day = localDay ?? ClosingAgentConstants.merchantLocalDay(now);
    final bounds = ClosingAgentConstants.utcBoundsForLocalDay(day, now: now);
    if (bounds == null) {
      return const Left(
        ValidationFailure(
          'localDay must be YYYY-MM-DD.',
          code: 'invalid_local_day',
        ),
      );
    }

    final result = await _transactionRepository.getCreatedOnLocalDay(
      day,
      now: now,
    );
    return result.fold(Left.new, (txns) => Right(_summarize(day, txns)));
  }

  ClosingDaySummary _summarize(String localDay, List<Transaction> txns) {
    var debtCount = 0;
    var paymentCount = 0;
    final debtByCurrency = <String, int>{};
    final paymentByCurrency = <String, int>{};

    for (final txn in txns) {
      if (txn.isDeleted || txn.isArchived) {
        continue;
      }
      switch (txn.type) {
        case TransactionType.debt:
          debtCount += 1;
          debtByCurrency[txn.currency] =
              (debtByCurrency[txn.currency] ?? 0) + txn.amount;
        case TransactionType.payment:
          paymentCount += 1;
          paymentByCurrency[txn.currency] =
              (paymentByCurrency[txn.currency] ?? 0) + txn.amount;
      }
    }

    final codes = {...debtByCurrency.keys, ...paymentByCurrency.keys}.toList()
      ..sort();
    final totals = [
      for (final code in codes)
        ClosingDayCurrencyTotals(
          currencyCode: code,
          debtMinor: debtByCurrency[code] ?? 0,
          paymentMinor: paymentByCurrency[code] ?? 0,
        ),
    ];

    return ClosingDaySummary(
      localDay: localDay,
      debtCount: debtCount,
      paymentCount: paymentCount,
      totals: totals,
    );
  }
}
