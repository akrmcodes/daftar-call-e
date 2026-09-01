import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Restores a soft-deleted ledger and its cascade.
class RestoreLedgerUseCase {
  /// Creates a use case that depends on the ledger repository contract.
  const RestoreLedgerUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  /// Restores the ledger identified by [ledgerId].
  ///
  /// Returns [Left(ValidationFailure)] when the identifier is blank.
  /// Returns [Left(DatabaseFailure)] when persistence fails.
  /// Returns [Left(Failure)] from the repository when the ledger cannot be
  /// restored.
  Future<Either<Failure, Ledger>> execute(String ledgerId) async {
    final normalizedLedgerId = ledgerId.trim();
    if (normalizedLedgerId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger id is required.',
          code: 'ledger_id_required',
        ),
      );
    }

    return _ledgerRepository.restore(normalizedLedgerId);
  }
}
