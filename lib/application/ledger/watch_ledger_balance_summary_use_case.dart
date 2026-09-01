import 'package:daftar/application/ledger/aggregate_balances_by_currency.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';

class WatchLedgerBalanceSummaryUseCase {
  const WatchLedgerBalanceSummaryUseCase(this._balanceRepository);

  final BalanceRepository _balanceRepository;

  Stream<List<ContactBalance>> execute(String ledgerId) {
    final normalizedLedgerId = ledgerId.trim();
    if (normalizedLedgerId.isEmpty) {
      return Stream.value(const <ContactBalance>[]);
    }

    return _balanceRepository.watchBalancesByLedger(normalizedLedgerId).map(
          (balances) => aggregateBalancesByCurrency(
            balances,
            summaryContactId: normalizedLedgerId,
          ),
        );
  }
}
