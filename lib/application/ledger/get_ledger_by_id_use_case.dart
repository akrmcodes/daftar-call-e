import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

class GetLedgerByIdUseCase {
  const GetLedgerByIdUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  Future<Either<Failure, Ledger>> execute(String ledgerId) {
    return _ledgerRepository.getById(ledgerId);
  }
}
