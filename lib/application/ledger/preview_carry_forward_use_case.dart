import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/value_objects/carry_forward_preview.dart';
import 'package:fpdart/fpdart.dart';

class PreviewCarryForwardUseCase {
  const PreviewCarryForwardUseCase(this._ledgerRepository);

  final LedgerRepository _ledgerRepository;

  Future<Either<Failure, CarryForwardPreview>> execute({
    required String sourceLedgerId,
    required String targetLedgerId,
  }) {
    return _ledgerRepository.previewCarryForward(
      sourceLedgerId: sourceLedgerId,
      targetLedgerId: targetLedgerId,
    );
  }
}
