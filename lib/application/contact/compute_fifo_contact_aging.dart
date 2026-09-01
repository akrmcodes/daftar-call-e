import 'package:daftar/domain/constants/reminder_tone_resolver.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/enums/transaction_type.dart';

/// FIFO aging for one contact in one currency (integer minor units).
///
/// Payments consume the oldest open debt first. Event order is
/// [Transaction.transactionDate] ascending, then [Transaction.createdAt],
/// then [Transaction.id] (not insert-time alone).
class FifoContactAging {
  /// Creates a FIFO aging slice.
  const FifoContactAging({
    required this.currencyCode,
    required this.openMinor,
    required this.ageDays,
    this.daysSinceLastPayment,
    this.daysSinceLastDebt,
  });

  /// ISO currency of this slice.
  final String currencyCode;

  /// Remaining unpaid debt after FIFO (positive minor units).
  final int openMinor;

  /// Calendar days from as-of to the oldest remaining debt date.
  final int ageDays;

  /// Calendar days since the latest payment, or null if none.
  final int? daysSinceLastPayment;

  /// Calendar days since the latest debt, or null if none.
  final int? daysSinceLastDebt;

  /// Adaptive tone (age base + recent-payer cap). [daysSinceLastDebt] unused.
  ReminderToneBand get toneBand => reminderToneBandForAging(
    ageDays: ageDays,
    daysSinceLastPayment: daysSinceLastPayment,
  );
}

/// Calendar-day difference in the device local timezone. Never negative.
int calendarDaysBetween(DateTime asOf, DateTime then) {
  final asOfDate = _localDateOnly(asOf);
  final thenDate = _localDateOnly(then);
  final days = asOfDate.difference(thenDate).inDays;
  return days < 0 ? 0 : days;
}

/// FIFO-allocates [transactions] in [currencyCode].
///
/// Returns null when no open debt remains in that currency (not overdue).
FifoContactAging? computeFifoContactAging({
  required List<Transaction> transactions,
  required String currencyCode,
  required DateTime asOf,
}) {
  final code = currencyCode.trim().toUpperCase();
  if (code.isEmpty) {
    return null;
  }

  final rows = [
    for (final transaction in transactions)
      if (!transaction.isDeleted &&
          transaction.amount > 0 &&
          transaction.currency.trim().toUpperCase() == code)
        transaction,
  ]..sort(_byEventThenId);

  if (rows.isEmpty) {
    return null;
  }

  final open = <_OpenDebt>[];
  DateTime? lastPayment;
  DateTime? lastDebt;

  for (final transaction in rows) {
    switch (transaction.type) {
      case TransactionType.debt:
        open.add(
          _OpenDebt(
            date: transaction.transactionDate,
            remaining: transaction.amount,
          ),
        );
        lastDebt = _later(lastDebt, transaction.transactionDate);
      case TransactionType.payment:
        var leftover = transaction.amount;
        while (leftover > 0 && open.isNotEmpty) {
          final head = open.first;
          if (leftover >= head.remaining) {
            leftover -= head.remaining;
            open.removeAt(0);
          } else {
            open[0] = _OpenDebt(
              date: head.date,
              remaining: head.remaining - leftover,
            );
            leftover = 0;
          }
        }
        lastPayment = _later(lastPayment, transaction.transactionDate);
    }
  }

  if (open.isEmpty) {
    return null;
  }

  var openMinor = 0;
  for (final slice in open) {
    openMinor += slice.remaining;
  }

  return FifoContactAging(
    currencyCode: code,
    openMinor: openMinor,
    ageDays: calendarDaysBetween(asOf, open.first.date),
    daysSinceLastPayment: lastPayment == null
        ? null
        : calendarDaysBetween(asOf, lastPayment),
    daysSinceLastDebt: lastDebt == null
        ? null
        : calendarDaysBetween(asOf, lastDebt),
  );
}

class _OpenDebt {
  const _OpenDebt({required this.date, required this.remaining});

  final DateTime date;
  final int remaining;
}

DateTime _localDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _later(DateTime? current, DateTime candidate) {
  if (current == null || candidate.isAfter(current)) {
    return candidate;
  }
  return current;
}

int _byEventThenId(Transaction left, Transaction right) {
  final byDate = left.transactionDate.compareTo(right.transactionDate);
  if (byDate != 0) {
    return byDate;
  }
  final byCreated = left.createdAt.compareTo(right.createdAt);
  if (byCreated != 0) {
    return byCreated;
  }
  return left.id.compareTo(right.id);
}
