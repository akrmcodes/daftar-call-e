import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Restores a soft-deleted contact and its cascade.
class RestoreContactUseCase {
  /// Creates a use case that depends on the contact repository contract.
  const RestoreContactUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  /// Restores the contact identified by [contactId].
  ///
  /// Returns [Left(ValidationFailure)] when the identifier is blank.
  /// Returns [Left(DatabaseFailure)] when persistence fails.
  /// Returns [Left(Failure)] from the repository when the contact cannot be
  /// restored.
  Future<Either<Failure, Contact>> execute(String contactId) async {
    final normalizedContactId = contactId.trim();
    if (normalizedContactId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact id is required.',
          code: 'contact_id_required',
        ),
      );
    }

    return _contactRepository.restore(normalizedContactId);
  }
}
