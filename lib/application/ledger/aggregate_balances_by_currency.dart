import 'package:daftar/domain/entities/contact_balance.dart';

/// Folds per-contact balance rows into one summary row per currency.
///
/// Sums total debt, total payment, and net balance for all rows sharing the
/// same ISO-4217 code (case-insensitive). Used for global and ledger summaries.
List<ContactBalance> aggregateBalancesByCurrency(
  List<ContactBalance> balances, {
  required String summaryContactId,
}) {
  if (balances.isEmpty) {
    return const <ContactBalance>[];
  }

  final byCurrency = <String, _AggregatedBalanceAccumulator>{};

  for (final balance in balances) {
    final currencyKey = balance.currencyCode.trim().toUpperCase();
    if (currencyKey.isEmpty) {
      continue;
    }

    byCurrency
        .putIfAbsent(
          currencyKey,
          _AggregatedBalanceAccumulator.new,
        )
        .add(balance);
  }

  final aggregated =
      byCurrency.entries
          .map(
            (entry) => ContactBalance(
              contactId: summaryContactId,
              currencyCode: entry.key,
              totalDebt: entry.value.totalDebt,
              totalPayment: entry.value.totalPayment,
              netBalance: entry.value.netBalance,
              lastUpdatedAt: entry.value.lastUpdatedAt,
            ),
          )
          .toList(growable: false)
        ..sort(
          (left, right) => left.currencyCode.compareTo(right.currencyCode),
        );

  return aggregated;
}

class _AggregatedBalanceAccumulator {
  int totalDebt = 0;
  int totalPayment = 0;
  int netBalance = 0;
  DateTime lastUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  void add(ContactBalance balance) {
    totalDebt += balance.totalDebt;
    totalPayment += balance.totalPayment;
    netBalance += balance.netBalance;

    if (balance.lastUpdatedAt.isAfter(lastUpdatedAt)) {
      lastUpdatedAt = balance.lastUpdatedAt;
    }
  }
}
