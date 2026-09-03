import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Updates a contact after validating the mutable fields.
class UpdateContactUseCase {
  /// Creates a use case that depends on the contact repository contract.
  const UpdateContactUseCase(
    this._contactRepository,
    this._ledgerRepository,
  );

  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;

  /// Validates the contact and forwards the update to the repository.
  Future<Either<Failure, Contact>> execute(Contact contact) async {
    final trimmedName = contact.name.trim();
    final normalizedName = trimmedName.normalizeArabic();
    if (normalizedName.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact name is required.',
          code: 'contact_name_required',
        ),
      );
    }

    if (!ContactEmail.isValid(contact.email)) {
      return const Left(
        ValidationFailure(
          'Contact email is invalid.',
          code: 'contact_email_invalid',
        ),
      );
    }

    final existingContacts = await _contactRepository
        .watchByLedger(contact.ledgerId)
        .first;
    final normalizedTargetName = normalizedName.toLowerCase();
    final duplicateExists = existingContacts.any(
      (existing) =>
          existing.id != contact.id &&
          existing.name.normalizeArabic().toLowerCase() == normalizedTargetName,
    );
    if (duplicateExists) {
      return const Left(
        ValidationFailure(
          'Name already exists',
          code: 'contact_name_exists',
        ),
      );
    }

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

    final normalizedContact = contact.copyWith(
      name: trimmedName,
      phone: _normalizeOptionalText(contact.phone),
      email: ContactEmail.normalize(contact.email),
      notes: _normalizeOptionalText(contact.notes),
      creditCurrency: _normalizeOptionalCurrency(contact.creditCurrency),
      updatedAt: DateTime.now().toUtc(),
      syncVersion: contact.syncVersion + 1,
    );

    return _contactRepository.update(
      UpdateContactParams(
        id: normalizedContact.id,
        name: normalizedContact.name,
        phone: normalizedContact.phone,
        email: normalizedContact.email,
        updateEmail: true,
        notes: normalizedContact.notes,
        creditLimit: normalizedContact.creditLimit,
        creditCurrency: normalizedContact.creditCurrency,
        doNotCall: normalizedContact.doNotCall,
      ),
    );
  }

  static String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  static String? _normalizeOptionalCurrency(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed.toUpperCase();
  }
}
