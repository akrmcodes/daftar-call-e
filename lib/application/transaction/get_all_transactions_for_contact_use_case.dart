import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Loads all active transactions for a contact without pagination limits.
///
/// Used for one-off heavy operations such as PDF statement export, where the
/// full dataset is required for accurate running balances and totals.
class GetAllTransactionsForContactUseCase {
  /// Creates the use case with a transaction repository dependency.
  const GetAllTransactionsForContactUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Returns all non-deleted transactions for [contactId].
  Future<Either<Failure, List<Transaction>>> execute(String contactId) {
    final normalizedId = contactId.trim();
    if (normalizedId.isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure(
            'Contact id is required.',
            code: 'transaction_contact_required',
          ),
        ),
      );
    }

    return _transactionRepository.getRawTransactionsByContact(normalizedId);
  }
}
