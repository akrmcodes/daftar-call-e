import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for calculating balances from raw transactions.
class CalculateBalanceParams {
  /// Creates calculation parameters for a contact.
  const CalculateBalanceParams({required this.contactId});

  /// The contact whose balances should be recalculated.
  final String contactId;
}

/// Recalculates balances from scratch for integrity verification.
class CalculateBalanceUseCase {
  /// Creates a use case that depends on the transaction repository contract.
  const CalculateBalanceUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Fetches raw transactions, groups them by currency, and returns balances.
  Future<Either<Failure, List<ContactBalance>>> execute(
    CalculateBalanceParams params,
  ) async {
    final normalizedContactId = params.contactId.trim();
    if (normalizedContactId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact id is required.',
          code: 'transaction_contact_required',
        ),
      );
    }

    try {
      final transactionsResult = await _transactionRepository
          .getRawTransactionsByContact(normalizedContactId);
      if (transactionsResult.isLeft()) {
        return Left(transactionsResult.getLeft().toNullable()!);
      }

      final transactions = transactionsResult.getRight().toNullable()!;
      if (transactions.isEmpty) {
        return const Right(<ContactBalance>[]);
      }

      return Right(
        _calculateBalances(
          contactId: normalizedContactId,
          transactions: transactions,
        ),
      );
    } on Object catch (error) {
      return Left(
        DatabaseFailure(
          'Failed to calculate balances: $error',
          code: 'database_error',
        ),
      );
    }
  }

  List<ContactBalance> _calculateBalances({
    required String contactId,
    required List<Transaction> transactions,
  }) {
    final byCurrency = <String, _BalanceAccumulator>{};

    for (final transaction in transactions) {
      if (transaction.isDeleted) {
        continue;
      }

      final currencyKey = transaction.currency.trim().toUpperCase();
      if (currencyKey.isEmpty) {
        continue;
      }

      final accumulator = byCurrency.putIfAbsent(
        currencyKey,
        _BalanceAccumulator.new,
      );

      switch (transaction.type) {
        case TransactionType.debt:
          accumulator.totalDebt += transaction.amount;
        case TransactionType.payment:
          accumulator.totalPayment += transaction.amount;
      }
    }

    final now = DateTime.now().toUtc();
    final balances =
        byCurrency.entries
            .map(
              (entry) => ContactBalance(
                contactId: contactId,
                currencyCode: entry.key,
                totalDebt: entry.value.totalDebt,
                totalPayment: entry.value.totalPayment,
                netBalance: entry.value.totalPayment - entry.value.totalDebt,
                lastUpdatedAt: now,
              ),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => left.currencyCode.compareTo(right.currencyCode),
          );

    return balances;
  }
}

class _BalanceAccumulator {
  int totalDebt = 0;
  int totalPayment = 0;
}
