import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:fpdart/fpdart.dart';

class SearchContactsUseCase {
  const SearchContactsUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  Future<Either<Failure, List<ContactSearchHit>>> execute(
    String query, {
    bool excludeUserArchivedLedgers = false,
  }) {
    return _contactRepository.search(
      query,
      excludeUserArchivedLedgers: excludeUserArchivedLedgers,
    );
  }
}
