import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/transaction_type.dart';

/// How the quick-add flow resolved a typed contact name ("Mohammed logic").
enum QuickAddAccountResolution {
  /// Name field empty — no search has run.
  idle,

  /// Exactly one ledger among matches — ledger auto-selected.
  singleLedgerAuto,

  /// Matches span multiple ledgers — user must pick a ledger.
  multiLedgerPick,

  /// No matches — treat as a new contact; user picks any ledger.
  newAccount,
}

/// Immutable UI state for the quick-add transaction bottom sheet.
class QuickAddState {
  const QuickAddState({
    required this.nameQuery,
    required this.amountMinorUnits,
    required this.transactionType,
    required this.selectedCurrencyCode,
    required this.matchedContacts,
    required this.selectedLedgerId,
    required this.availableLedgers,
    required this.accountResolution,
    required this.isSearchingName,
    required this.note,
    this.selectedContactId,
    this.searchFailure,
  });

  /// Empty form with ledgers loaded.
  factory QuickAddState.initial({
    required List<Ledger> availableLedgers,
    String? selectedLedgerId,
    String defaultCurrency = 'YER',
  }) {
    final normalizedCurrency = defaultCurrency.trim().toUpperCase();
    return QuickAddState(
      nameQuery: '',
      amountMinorUnits: null,
      transactionType: TransactionType.debt,
      selectedCurrencyCode: normalizedCurrency.isNotEmpty
          ? normalizedCurrency
          : 'YER',
      matchedContacts: const [],
      selectedLedgerId:
          selectedLedgerId ?? primaryLedgerId(availableLedgers),
      availableLedgers: availableLedgers,
      accountResolution: QuickAddAccountResolution.idle,
      isSearchingName: false,
      note: '',
    );
  }

  /// Raw text in the name field (may include trailing spaces while typing).
  final String nameQuery;

  /// Amount in smallest currency unit; null until the user enters a value.
  final int? amountMinorUnits;

  /// [TransactionType.payment] = له (credit). [TransactionType.debt] = عليه.
  final TransactionType transactionType;

  /// ISO 4217 code for the transaction amount (multi-currency mode only).
  final String selectedCurrencyCode;

  /// Contacts returned by the latest debounced name search.
  final List<Contact> matchedContacts;

  /// Selected ledger UUID, or null when the user must choose (multi-ledger matches).
  final String? selectedLedgerId;

  /// All active ledgers, ordered by sort order.
  final List<Ledger> availableLedgers;

  /// Outcome of the last name resolution pass.
  final QuickAddAccountResolution accountResolution;

  /// True while a debounced name search is in flight.
  final bool isSearchingName;

  /// Optional item/category note (persisted as transaction itemName).
  final String note;

  /// Set when the user taps an autocomplete suggestion.
  final String? selectedContactId;

  /// Set when the last contact search failed.
  final Failure? searchFailure;

  /// True when [transactionType] is payment (له).
  bool get isCredit => transactionType == TransactionType.payment;

  /// True when the typed name has no contact matches.
  bool get isNewAccount =>
      accountResolution == QuickAddAccountResolution.newAccount;

  /// Whether to show the horizontal contact suggestion strip.
  bool get showContactSuggestions {
    if (isSearchingName || matchedContacts.isEmpty) {
      return false;
    }
    if (selectedContactId != null) {
      return false;
    }
    if (matchedContacts.length == 1) {
      final only = matchedContacts.first;
      return nameQuery.trim().normalizeArabic() !=
          only.name.trim().normalizeArabic();
    }
    return true;
  }

  /// Ledgers shown in the ledger picker for the current resolution mode.
  List<Ledger> get ledgersForPicker {
    switch (accountResolution) {
      case QuickAddAccountResolution.multiLedgerPick:
        final ledgerIds =
            matchedContacts.map((contact) => contact.ledgerId).toSet();
        return availableLedgers
            .where((ledger) => ledgerIds.contains(ledger.id))
            .toList(growable: false);
      case QuickAddAccountResolution.newAccount:
      case QuickAddAccountResolution.idle:
      case QuickAddAccountResolution.singleLedgerAuto:
        return availableLedgers;
    }
  }

  /// Primary ledger = lowest [Ledger.sortOrder], then name.
  static String? primaryLedgerId(List<Ledger> ledgers) {
    if (ledgers.isEmpty) {
      return null;
    }
    final sorted = List<Ledger>.from(ledgers)
      ..sort(
        (left, right) {
          final order = left.sortOrder.compareTo(right.sortOrder);
          if (order != 0) {
            return order;
          }
          return left.name.compareTo(right.name);
        },
      );
    return sorted.first.id;
  }

  QuickAddState copyWith({
    String? nameQuery,
    int? amountMinorUnits,
    bool clearAmount = false,
    TransactionType? transactionType,
    String? selectedCurrencyCode,
    List<Contact>? matchedContacts,
    String? selectedLedgerId,
    bool clearSelectedLedgerId = false,
    List<Ledger>? availableLedgers,
    QuickAddAccountResolution? accountResolution,
    bool? isSearchingName,
    String? note,
    String? selectedContactId,
    bool clearSelectedContactId = false,
    Failure? searchFailure,
    bool clearSearchFailure = false,
  }) {
    return QuickAddState(
      nameQuery: nameQuery ?? this.nameQuery,
      amountMinorUnits:
          clearAmount ? null : (amountMinorUnits ?? this.amountMinorUnits),
      transactionType: transactionType ?? this.transactionType,
      selectedCurrencyCode:
          selectedCurrencyCode ?? this.selectedCurrencyCode,
      matchedContacts: matchedContacts ?? this.matchedContacts,
      selectedLedgerId: clearSelectedLedgerId
          ? null
          : (selectedLedgerId ?? this.selectedLedgerId),
      availableLedgers: availableLedgers ?? this.availableLedgers,
      accountResolution: accountResolution ?? this.accountResolution,
      isSearchingName: isSearchingName ?? this.isSearchingName,
      note: note ?? this.note,
      selectedContactId: clearSelectedContactId
          ? null
          : (selectedContactId ?? this.selectedContactId),
      searchFailure:
          clearSearchFailure ? null : (searchFailure ?? this.searchFailure),
    );
  }
}
