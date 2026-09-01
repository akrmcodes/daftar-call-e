import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Soft-deletes a contact after loading it from the repository.
class DeleteContactUseCase {
  /// Creates a use case that depends on the contact repository contract.
  const DeleteContactUseCase(
    this._contactRepository,
    this._ledgerRepository,
  );

  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;

  /// Fetches the contact, marks it deleted, and persists the change.
  Future<Either<Failure, Contact>> execute(String contactId) async {
    final contactResult = await _contactRepository.getById(contactId);
    return contactResult.fold(
      Left.new,
      (contact) async {
        final ledgerResult = await _ledgerRepository.getById(contact.ledgerId);
        if (ledgerResult.isLeft()) {
          return Left(ledgerResult.getLeft().toNullable()!);
        }

        final archivedFailure = rejectIfUserArchived(
          ledgerResult.getRight().toNullable()!,
        );
        if (archivedFailure != null) {
          return Left(archivedFailure.getLeft().toNullable()!);
        }

        final softDeletedContact = contact.copyWith(
          isDeleted: true,
          updatedAt: DateTime.now().toUtc(),
          syncVersion: contact.syncVersion + 1,
        );

        final deleteResult = await _contactRepository.delete(contactId);
        return deleteResult.fold(
          Left.new,
          (_) => Right(softDeletedContact),
        );
      },
    );
  }
}
