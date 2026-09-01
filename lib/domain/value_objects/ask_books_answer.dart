import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:equatable/equatable.dart';

/// One Drift balance row for ask-the-books (integer minor units).
class AskBooksBalanceRow extends Equatable {
  /// Creates a row.
  const AskBooksBalanceRow({
    required this.contactId,
    required this.contactName,
    required this.netBalance,
    required this.currencyCode,
  });

  /// Contact UUID.
  final String contactId;

  /// Display name from Drift.
  final String contactName;

  /// Signed net (`totalPayment - totalDebt`). Negative = they owe us.
  final int netBalance;

  /// ISO currency for [netBalance].
  final String currencyCode;

  /// Absolute outstanding when [netBalance] is negative.
  int get owedMinor => netBalance < 0 ? -netBalance : 0;

  @override
  List<Object?> get props => [contactId, contactName, netBalance, currencyCode];
}

/// Device-authored answer to an ask-the-books goal. Amounts come from Drift.
sealed class AskBooksAnswer extends Equatable {
  const AskBooksAnswer();
}

/// Contacts with any currency `netBalance < 0`. Empty list is a successful empty book.
class AskBooksOverdueList extends AskBooksAnswer {
  /// Creates an overdue list.
  const AskBooksOverdueList(this.rows);

  /// Overdue rows (may be empty), largest [AskBooksBalanceRow.owedMinor] first.
  final List<AskBooksBalanceRow> rows;

  @override
  List<Object?> get props => [rows];
}

/// Same overdue population, titled as largest outstanding.
class AskBooksLargestOutstanding extends AskBooksAnswer {
  /// Creates a largest-outstanding list.
  const AskBooksLargestOutstanding(this.rows);

  /// Rows sorted by [AskBooksBalanceRow.owedMinor] descending.
  final List<AskBooksBalanceRow> rows;

  @override
  List<Object?> get props => [rows];
}

/// Same overdue population, titled as smallest outstanding.
class AskBooksSmallestOutstanding extends AskBooksAnswer {
  /// Creates a smallest-outstanding list.
  const AskBooksSmallestOutstanding(this.rows);

  /// Rows sorted by [AskBooksBalanceRow.owedMinor] ascending.
  final List<AskBooksBalanceRow> rows;

  @override
  List<Object?> get props => [rows];
}

/// A named contact's current balance.
class AskBooksNamedBalance extends AskBooksAnswer {
  /// Creates a named-balance answer.
  const AskBooksNamedBalance(this.row);

  /// Drift row for the resolved contact.
  final AskBooksBalanceRow row;

  @override
  List<Object?> get props => [row];
}

/// Latest debt or payment for a named contact.
class AskBooksLastTransaction extends AskBooksAnswer {
  /// Creates a last-transaction answer.
  const AskBooksLastTransaction({
    required this.contactId,
    required this.contactName,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionDate,
    required this.type,
  });

  /// Contact UUID.
  final String contactId;

  /// Display name from Drift.
  final String contactName;

  /// Positive integer minor units.
  final int amountMinor;

  /// ISO currency.
  final String currencyCode;

  /// Transaction date (UTC).
  final DateTime transactionDate;

  /// Debt or payment.
  final TransactionType type;

  @override
  List<Object?> get props => [
    contactId,
    contactName,
    amountMinor,
    currencyCode,
    transactionDate,
    type,
  ];
}

/// Named contact has no transaction of the requested type.
class AskBooksNoLastTransaction extends AskBooksAnswer {
  /// Creates an empty last-transaction answer.
  const AskBooksNoLastTransaction({
    required this.contactId,
    required this.contactName,
    required this.type,
  });

  /// Contact UUID.
  final String contactId;

  /// Display name from Drift.
  final String contactName;

  /// Requested type.
  final TransactionType type;

  @override
  List<Object?> get props => [contactId, contactName, type];
}

/// Named ask matched more than one contact — merchant must pick.
class AskBooksAmbiguous extends AskBooksAnswer {
  /// Creates an ambiguous answer.
  const AskBooksAmbiguous(this.candidates);

  /// FTS candidates (length > 1).
  final List<ContactSearchHit> candidates;

  @override
  List<Object?> get props => [candidates];
}

/// Named ask matched no contact.
class AskBooksUnresolved extends AskBooksAnswer {
  /// Creates an unresolved named ask.
  const AskBooksUnresolved();

  @override
  List<Object?> get props => const [];
}

/// Named/last-txn ask with no usable name and no prior contact.
class AskBooksNeedName extends AskBooksAnswer {
  /// Creates a need-name answer.
  const AskBooksNeedName();

  @override
  List<Object?> get props => const [];
}
