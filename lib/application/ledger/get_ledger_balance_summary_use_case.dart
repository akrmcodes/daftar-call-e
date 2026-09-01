import 'package:daftar/application/ledger/aggregate_balances_by_currency.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Loads a ledger-wide balance summary for AI-safe snapshot reads.
///
/// Returns one [ContactBalance] per currency with totals summed across every
/// active contact in the ledger.
class GetLedgerBalanceSummaryUseCase {
  /// Creates a use case that depends on the ledger, contact, and balance
  /// repository contracts.
  const GetLedgerBalanceSummaryUseCase(
    this._ledgerRepository,
    this._contactRepository,
    this._balanceRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ContactRepository _contactRepository;
  final BalanceRepository _balanceRepository;

  /// Returns the active contacts' balance rows for the selected ledger.
  Future<Either<Failure, List<ContactBalance>>> execute(String ledgerId) async {
    final normalizedLedgerId = ledgerId.trim();
    if (normalizedLedgerId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger id is required.',
          code: 'ledger_id_required',
        ),
      );
    }

    final ledgerResult = await _ledgerRepository.getById(normalizedLedgerId);
    if (ledgerResult.isLeft()) {
      return Left(ledgerResult.getLeft().toNullable()!);
    }

    final contactsResult = await _contactRepository.getByLedger(
      normalizedLedgerId,
    );
    if (contactsResult.isLeft()) {
      return Left(contactsResult.getLeft().toNullable()!);
    }

    final contacts = contactsResult.getRight().toNullable()!;
    if (contacts.isEmpty) {
      return const Right(<ContactBalance>[]);
    }

    final balances = <ContactBalance>[];
    for (final contact in contacts) {
      final contactBalancesResult = await _balanceRepository.getByContact(
        contact.id,
      );
      if (contactBalancesResult.isLeft()) {
        return Left(contactBalancesResult.getLeft().toNullable()!);
      }

      balances.addAll(contactBalancesResult.getRight().toNullable()!);
    }

    return Right(
      aggregateBalancesByCurrency(
        balances,
        summaryContactId: normalizedLedgerId,
      ),
    );
  }
}
