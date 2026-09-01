import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';

class GetArchivedLedgersUseCase {
  const GetArchivedLedgersUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  Stream<List<Ledger>> execute() {
    return _ledgerRepository.watchArchived();
  }
}
