import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';

/// Streams contact summaries for a ledger in a single reactive query.
///
/// Each emission includes per-contact balances and transaction counts,
/// replacing per-tile balance and count provider watches in list UIs.
class GetContactSummariesUseCase {
  /// Creates a use case backed by the contact repository contract.
  const GetContactSummariesUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  /// Returns a live summary stream for [ledgerId].
  Stream<List<ContactWithSummary>> execute(String ledgerId) {
    return _contactRepository.watchContactSummariesByLedger(ledgerId);
  }
}
