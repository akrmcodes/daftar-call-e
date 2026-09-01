import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Updates mutable ledger fields after validating the input.
class UpdateLedgerUseCase {
  /// Creates a use case that depends on the ledger repository contract.
  const UpdateLedgerUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  /// Validates the ledger and forwards the update to the repository.
  Future<Either<Failure, Ledger>> execute(Ledger updatedLedger) async {
    final normalizedName = updatedLedger.name.trim();
    if (normalizedName.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger name is required.',
          code: 'ledger_name_required',
        ),
      );
    }

    final existingResult = await _ledgerRepository.getById(updatedLedger.id);
    if (existingResult.isLeft()) {
      return Left(existingResult.getLeft().toNullable()!);
    }

    final archivedFailure = rejectIfUserArchived(
      existingResult.getRight().toNullable()!,
    );
    if (archivedFailure != null) {
      return Left(archivedFailure.getLeft().toNullable()!);
    }

    final normalizedLedger = updatedLedger.copyWith(
      name: normalizedName,
      updatedAt: DateTime.now().toUtc(),
      syncVersion: updatedLedger.syncVersion + 1,
    );

    return _ledgerRepository.update(
      UpdateLedgerParams(
        id: normalizedLedger.id,
        name: normalizedLedger.name,
        icon: normalizedLedger.icon,
        color: normalizedLedger.color,
        sortOrder: normalizedLedger.sortOrder,
      ),
    );
  }
}
