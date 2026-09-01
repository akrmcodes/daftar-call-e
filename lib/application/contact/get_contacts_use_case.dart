import 'package:daftar/core/extensions/string_extensions.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';

/// Streams contacts for a ledger with application-level sorting.
class GetContactsUseCase {
  /// Creates a use case that depends on the contact repository contract.
  const GetContactsUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  /// Returns a sorted contact stream for the selected ledger.
  Stream<List<Contact>> execute(String ledgerId, {String sortBy = 'recent'}) {
    return _contactRepository
        .watchByLedger(ledgerId)
        .map(
          (contacts) => _sortContacts(contacts, sortBy),
        );
  }

  List<Contact> _sortContacts(List<Contact> contacts, String sortBy) {
    final sortedContacts = List<Contact>.from(contacts);
    final normalizedSortBy = sortBy.trim().toLowerCase();
    if (normalizedSortBy == 'name') {
      sortedContacts.sort(_compareByName);
    } else {
      sortedContacts.sort(_compareByRecent);
    }

    return sortedContacts;
  }

  int _compareByName(Contact left, Contact right) {
    final leftName = _normalizedName(left.name);
    final rightName = _normalizedName(right.name);

    final primaryComparison = leftName.compareTo(rightName);
    if (primaryComparison != 0) {
      return primaryComparison;
    }

    return right.updatedAt.compareTo(left.updatedAt);
  }

  int _compareByRecent(Contact left, Contact right) {
    final primaryComparison = right.updatedAt.compareTo(left.updatedAt);
    if (primaryComparison != 0) {
      return primaryComparison;
    }

    return _normalizedName(left.name).compareTo(_normalizedName(right.name));
  }

  String _normalizedName(String value) => value.normalizeArabic().toLowerCase();
}
