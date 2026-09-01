import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for restoring a previously deleted transaction.
class RestoreTransactionParams {
  /// Creates restore parameters for a transaction.
  const RestoreTransactionParams({required this.id});

  /// The transaction identifier.
  final String id;
}

/// Restores a soft-deleted transaction and lets the repository recalculate.
class RestoreTransactionUseCase {
  /// Creates a use case that depends on the transaction repository contract.
  const RestoreTransactionUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Validates the identifier and delegates the restore.
  Future<Either<Failure, Unit>> execute(
    RestoreTransactionParams params,
  ) async {
    final normalizedId = params.id.trim();
    if (normalizedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Transaction id is required.',
          code: 'transaction_id_required',
        ),
      );
    }

    try {
      return await _transactionRepository.restoreTransaction(normalizedId);
    } on Object catch (error) {
      return Left(
        DatabaseFailure(
          'Failed to restore transaction: $error',
          code: 'database_error',
        ),
      );
    }
  }
}
