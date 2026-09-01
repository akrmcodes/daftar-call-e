import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for deleting an existing transaction.
class DeleteTransactionParams {
  /// Creates delete parameters for a transaction.
  const DeleteTransactionParams({required this.id});

  /// The transaction identifier.
  final String id;
}

/// Soft-deletes a transaction and lets the repository recalculate balances.
class DeleteTransactionUseCase {
  /// Creates a use case that depends on the transaction repository contract.
  const DeleteTransactionUseCase(
    this._transactionRepository,
    this._contactRepository,
    this._ledgerRepository,
  );

  final TransactionRepository _transactionRepository;
  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;

  /// Validates the identifier and delegates the soft-delete.
  Future<Either<Failure, Unit>> execute(DeleteTransactionParams params) async {
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
      final existingResult = await _transactionRepository.getById(normalizedId);
      if (existingResult.isLeft()) {
        return Left(existingResult.getLeft().toNullable()!);
      }

      final existingTransaction = existingResult.getRight().toNullable()!;
      final contactResult = await _contactRepository.getById(
        existingTransaction.contactId,
      );
      if (contactResult.isLeft()) {
        return Left(contactResult.getLeft().toNullable()!);
      }

      final ledgerResult = await _ledgerRepository.getById(
        contactResult.getRight().toNullable()!.ledgerId,
      );
      if (ledgerResult.isLeft()) {
        return Left(ledgerResult.getLeft().toNullable()!);
      }

      final archivedFailure = rejectIfUserArchived(
        ledgerResult.getRight().toNullable()!,
      );
      if (archivedFailure != null) {
        return Left(archivedFailure.getLeft().toNullable()!);
      }

      return await _transactionRepository.deleteTransaction(normalizedId);
    } on Object catch (error) {
      return Left(
        DatabaseFailure(
          'Failed to delete transaction: $error',
          code: 'database_error',
        ),
      );
    }
  }
}
