import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';

/// Streams the current active ledgers.
class GetLedgersUseCase {
  /// Creates a use case that depends on the ledger repository contract.
  const GetLedgersUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  /// Returns the repository stream of active ledgers.
  Stream<List<Ledger>> execute() {
    return _ledgerRepository.watchAll();
  }
}
