import 'package:daftar/application/ledger/aggregate_balances_by_currency.dart';
import 'package:daftar/application/ledger/ledger_summary_export_data.dart';
import 'package:daftar/application/ledger/select_contact_net_balance.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Loads ledger metadata, contacts, and balances for PDF summary export.
///
/// Returns [ValidationFailure] when the ledger id is empty, or repository
/// failures from ledger, contact, or balance reads. Contacts are sorted by name.
class PrepareLedgerSummaryExportUseCase {
  /// Creates a use case with repository contracts injected.
  const PrepareLedgerSummaryExportUseCase(
    this._ledgerRepository,
    this._contactRepository,
    this._balanceRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ContactRepository _contactRepository;
  final BalanceRepository _balanceRepository;

  /// Fetches and shapes all data required to render a ledger summary PDF.
  Future<Either<Failure, LedgerSummaryExportData>> execute(
    String ledgerId,
  ) async {
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

    final ledger = ledgerResult.getRight().toNullable()!;

    final contactsResult = await _contactRepository.getByLedger(
      normalizedLedgerId,
    );
    if (contactsResult.isLeft()) {
      return Left(contactsResult.getLeft().toNullable()!);
    }

    final contacts = List<Contact>.from(contactsResult.getRight().toNullable()!)
      ..sort(_compareByName);

    final rows = <LedgerSummaryContactRow>[];
    final allBalances = <ContactBalance>[];

    for (final contact in contacts) {
      final balancesResult = await _balanceRepository.getByContact(contact.id);
      if (balancesResult.isLeft()) {
        return Left(balancesResult.getLeft().toNullable()!);
      }

      final balances = balancesResult.getRight().toNullable()!;
      allBalances.addAll(balances);

      final phone = contact.phone?.trim();
      rows.add(
        LedgerSummaryContactRow(
          name: contact.name,
          phone: phone == null || phone.isEmpty ? null : phone,
          netBalance: selectContactNetBalance(contact, balances),
          currencyCode: selectContactDisplayCurrency(contact, balances),
        ),
      );
    }

    final ledgerTotals = aggregateBalancesByCurrency(
      allBalances,
      summaryContactId: normalizedLedgerId,
    );

    return Right(
      LedgerSummaryExportData(
        ledgerName: ledger.name,
        contacts: rows,
        ledgerTotals: ledgerTotals,
      ),
    );
  }

  int _compareByName(Contact left, Contact right) {
    final nameComparison = _sortKey(left.name).compareTo(_sortKey(right.name));
    if (nameComparison != 0) {
      return nameComparison;
    }

    return right.updatedAt.compareTo(left.updatedAt);
  }

  String _sortKey(String value) => value.normalizeArabic().toLowerCase();
}
