import 'package:daftar/application/ledger/aggregate_balances_by_currency.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'balance_providers.g.dart';

const String _globalBalanceContactId = 'global';

/// Balance updates are fully reactive.
///
/// `BalanceRepository.watchByContact()` listens to the derived
/// `contact_balances` Drift table, and transaction writes recalculate that
/// table atomically in the same database transaction. Riverpod only exposes
/// the stream to the UI here, so no manual invalidation is needed.
/// Streams per-contact balance rows.
@riverpod
Stream<List<ContactBalance>> contactBalance(Ref ref, String contactId) {
  return ref.watch(balanceRepositoryProvider).watchByContact(contactId);
}

/// Streams the app-wide balance summary grouped by currency.
@riverpod
Stream<List<ContactBalance>> globalBalances(Ref ref) {
  return ref
      .watch(balanceRepositoryProvider)
      .watchAllBalances()
      .map(
        (balances) => aggregateBalancesByCurrency(
          balances,
          summaryContactId: _globalBalanceContactId,
        ),
      );
}

/// Streams the ledger-level balance summary across all contacts (per currency).
@riverpod
Stream<List<ContactBalance>> ledgerBalanceSummary(Ref ref, String ledgerId) {
  return ref.watch(watchLedgerBalanceSummaryUseCaseProvider).execute(ledgerId);
}
