import 'package:daftar/domain/repositories/contact_repository.dart';

/// Streams the active contact count for a ledger via SQL `COUNT(*)`.
///
/// Avoids materializing full contact lists when only a count badge is needed.
class WatchContactCountUseCase {
  /// Creates a use case backed by the contact repository contract.
  const WatchContactCountUseCase(this._contactRepository);

  final ContactRepository _contactRepository;

  /// Returns a live count stream for [ledgerId].
  Stream<int> execute(String ledgerId) {
    return _contactRepository.watchContactCountByLedger(ledgerId);
  }
}
