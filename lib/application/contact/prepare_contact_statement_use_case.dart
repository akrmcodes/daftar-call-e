import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/ledger/select_contact_net_balance.dart';
import 'package:daftar/application/transaction/get_all_transactions_for_contact_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/value_objects/contact_statement_export.dart';
import 'package:fpdart/fpdart.dart';

/// Loads Drift contact, display-currency balance, and txns for a statement PDF.
class PrepareContactStatementUseCase {
  /// Creates the use case.
  const PrepareContactStatementUseCase({
    required GetContactByIdUseCase getContactByIdUseCase,
    required GetAllTransactionsForContactUseCase
    getAllTransactionsForContactUseCase,
    required BalanceRepository balanceRepository,
  }) : _getContactByIdUseCase = getContactByIdUseCase,
       _getAllTransactionsForContactUseCase =
           getAllTransactionsForContactUseCase,
       _balanceRepository = balanceRepository;

  final GetContactByIdUseCase _getContactByIdUseCase;
  final GetAllTransactionsForContactUseCase _getAllTransactionsForContactUseCase;
  final BalanceRepository _balanceRepository;

  /// Returns statement inputs. Empty [contactId] is `contact_id_required`.
  Future<Either<Failure, ContactStatementExport>> execute({
    required String contactId,
  }) async {
    final id = contactId.trim();
    if (id.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact id is required.',
          code: 'contact_id_required',
        ),
      );
    }

    final contactResult = await _getContactByIdUseCase.execute(id);
    if (contactResult.isLeft()) {
      return Left(contactResult.getLeft().toNullable()!);
    }
    final contact = contactResult.getRight().toNullable()!;

    final txnsResult = await _getAllTransactionsForContactUseCase.execute(id);
    if (txnsResult.isLeft()) {
      return Left(txnsResult.getLeft().toNullable()!);
    }
    final transactions = txnsResult.getRight().toNullable() ?? const [];

    final balancesResult = await _balanceRepository.getByContact(id);
    if (balancesResult.isLeft()) {
      return Left(balancesResult.getLeft().toNullable()!);
    }
    final balances = balancesResult.getRight().toNullable() ?? const [];

    return Right(
      ContactStatementExport(
        contact: contact,
        balance: _displayBalance(contact, balances),
        transactions: List.unmodifiable(transactions),
      ),
    );
  }

  static ContactBalance _displayBalance(
    Contact contact,
    List<ContactBalance> balances,
  ) {
    final currency = selectContactDisplayCurrency(contact, balances);
    final code = currency.isEmpty ? 'YER' : currency;
    if (balances.isNotEmpty) {
      for (final row in balances) {
        if (row.currencyCode.trim().toUpperCase() == code) {
          return row;
        }
      }
      return balances.first;
    }
    return ContactBalance(
      contactId: contact.id,
      currencyCode: code,
      totalDebt: 0,
      totalPayment: 0,
      netBalance: 0,
      lastUpdatedAt: DateTime.now().toUtc(),
    );
  }
}
