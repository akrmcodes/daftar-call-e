import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Soft-deletes a ledger after loading it from the repository.
class DeleteLedgerUseCase {
  /// Creates a use case that depends on the ledger repository contract.
  const DeleteLedgerUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  /// Fetches the ledger, marks it deleted, and persists the change.
  Future<Either<Failure, Ledger>> execute(String ledgerId) async {
    final ledgerResult = await _ledgerRepository.getById(ledgerId);
    return ledgerResult.fold(
      Left.new,
      (ledger) async {
        final softDeletedLedger = ledger.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now().toUtc(),
          syncVersion: ledger.syncVersion + 1,
        );

        final deleteResult = await _ledgerRepository.delete(ledgerId);
        return deleteResult.fold(
          Left.new,
          (_) => Right(softDeletedLedger),
        );
      },
    );
  }
}
