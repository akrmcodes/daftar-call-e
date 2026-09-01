import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:daftar/application/contact/get_contact_by_id_use_case.dart';
import 'package:daftar/application/contact/search_contacts_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:fpdart/fpdart.dart';

/// Resolves a proposal contact from an id or a unique name hint.
class ResolveAgentContactUseCase {
  /// Creates the use case.
  const ResolveAgentContactUseCase({
    required GetContactByIdUseCase getContactByIdUseCase,
    required SearchContactsUseCase searchContactsUseCase,
  }) : _getContactByIdUseCase = getContactByIdUseCase,
       _searchContactsUseCase = searchContactsUseCase;

  final GetContactByIdUseCase _getContactByIdUseCase;
  final SearchContactsUseCase _searchContactsUseCase;

  /// Returns exactly one contact, or [ValidationFailure] `contact_unresolved`.
  Future<Either<Failure, Contact>> execute({
    required String contactHint,
    String? contactId,
  }) async {
    final trimmedId = contactId?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) {
      return _getContactByIdUseCase.execute(trimmedId);
    }

    final hint = contactHint.trim();
    if (hint.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact could not be resolved.',
          code: 'contact_unresolved',
        ),
      );
    }

    final search = await _searchContactsUseCase.execute(hint);
    if (search.isLeft()) {
      return Left(search.getLeft().toNullable()!);
    }
    final hits = search.getRight().toNullable() ?? const [];
    if (hits.length != 1) {
      return const Left(
        ValidationFailure(
          'Contact could not be resolved.',
          code: 'contact_unresolved',
        ),
      );
    }
    final contact = hits.single.contact;
    if (!isExactContactNameMatch(hint, contact.name)) {
      return const Left(
        ValidationFailure(
          'Contact could not be resolved.',
          code: 'contact_unresolved',
        ),
      );
    }
    return Right(contact);
  }
}
