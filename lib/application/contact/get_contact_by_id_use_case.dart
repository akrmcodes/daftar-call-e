import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Loads a single contact by identifier for UI and AI-safe reads.
class GetContactByIdUseCase {
  /// Creates a use case that depends on the contact repository contract.
  const GetContactByIdUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  /// Returns the active contact for the given identifier.
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

    return _contactRepository.getById(normalizedContactId);
  }
}
