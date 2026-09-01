import 'package:daftar/application/transaction/quick_add_state.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';

/// Result of applying the quick-add "Mohammed logic" to contact search hits.
class QuickAddNameResolution {
  const QuickAddNameResolution({
    required this.mode,
    required this.selectedLedgerId,
  });

  final QuickAddAccountResolution mode;
  final String? selectedLedgerId;
}

/// Pure resolver for quick-add ledger selection from contact search results.
class QuickAddNameResolver {
  const QuickAddNameResolver._();

  /// Applies Mohammed logic:
  ///
  /// - 0 matches → new-account mode, primary ledger selected.
  /// - Matches in exactly 1 ledger → auto-select that ledger.
  /// - Matches in 2+ ledgers → selected ledger cleared (user must choose).
  static QuickAddNameResolution resolve({
    required List<Contact> matches,
    required List<Ledger> availableLedgers,
  }) {
    final primaryId = QuickAddState.primaryLedgerId(availableLedgers);

    if (matches.isEmpty) {
      return QuickAddNameResolution(
        mode: QuickAddAccountResolution.newAccount,
        selectedLedgerId: primaryId,
      );
    }

    final distinctLedgerIds =
        matches.map((contact) => contact.ledgerId).toSet();

    if (distinctLedgerIds.length == 1) {
      return QuickAddNameResolution(
        mode: QuickAddAccountResolution.singleLedgerAuto,
        selectedLedgerId: distinctLedgerIds.first,
      );
    }

    return const QuickAddNameResolution(
      mode: QuickAddAccountResolution.multiLedgerPick,
      selectedLedgerId: null,
    );
  }

  /// Keeps a manual ledger pick valid when the ledger list refreshes.
  static String? reconcileSelectedLedger({
    required String? current,
    required QuickAddAccountResolution resolution,
    required List<Ledger> availableLedgers,
    required List<Contact> matchedContacts,
  }) {
    if (availableLedgers.isEmpty) {
      return null;
    }

    final validIds = availableLedgers.map((ledger) => ledger.id).toSet();
    if (current != null && validIds.contains(current)) {
      if (resolution == QuickAddAccountResolution.multiLedgerPick) {
        final matchLedgerIds =
            matchedContacts.map((contact) => contact.ledgerId).toSet();
        if (matchLedgerIds.contains(current)) {
          return current;
        }
        return null;
      }
      return current;
    }

    return switch (resolution) {
      QuickAddAccountResolution.idle ||
      QuickAddAccountResolution.newAccount ||
      QuickAddAccountResolution.singleLedgerAuto =>
        QuickAddState.primaryLedgerId(availableLedgers),
      QuickAddAccountResolution.multiLedgerPick => null,
    };
  }
}
