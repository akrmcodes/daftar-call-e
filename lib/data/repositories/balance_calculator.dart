import 'package:daftar/data/models/balance_model.dart';
import 'package:daftar/data/models/transaction_model.dart';
import 'package:daftar/domain/enums/transaction_type.dart';

/// Calculates denormalized contact balances from a list of transactions.
List<BalanceModel> calculateContactBalances({
  required String contactId,
  required Iterable<TransactionModel> transactions,
  required DateTime lastUpdatedAt,
}) {
  final byCurrency = <String, _BalanceAccumulator>{};

  for (final transaction in transactions) {
    if (transaction.isDeleted) {
      continue;
    }

    final accumulator = byCurrency.putIfAbsent(
      transaction.currency,
      _BalanceAccumulator.new,
    );

    switch (transaction.type) {
      case TransactionType.debt:
        accumulator.totalDebt += transaction.amount;
      case TransactionType.payment:
        accumulator.totalPayment += transaction.amount;
    }
  }

  final balances =
      byCurrency.entries
          .map(
            (entry) => BalanceModel(
              contactId: contactId,
              currencyCode: entry.key,
              totalDebt: entry.value.totalDebt,
              totalPayment: entry.value.totalPayment,
              netBalance: entry.value.totalPayment - entry.value.totalDebt,
              lastUpdatedAt: lastUpdatedAt,
            ),
          )
          .toList(growable: false)
        ..sort(
          (left, right) => left.currencyCode.compareTo(right.currencyCode),
        );

  return balances;
}

class _BalanceAccumulator {
  int totalDebt = 0;
  int totalPayment = 0;
}
