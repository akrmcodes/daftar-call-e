import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:fpdart/fpdart.dart';

class UnarchiveLedgerUseCase {
  const UnarchiveLedgerUseCase(
    this._ledgerRepository,
    this._activationRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ActivationRepository _activationRepository;

  Future<Either<Failure, Ledger>> execute(String ledgerId) async {
    final normalizedId = ledgerId.trim();
    if (normalizedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Ledger id is required.',
          code: 'ledger_id_required',
        ),
      );
    }

    final isUnlocked = await _activationRepository.isFeatureUnlocked(
      FeatureFlag.ledgerArchiving,
    );
    if (!isUnlocked) {
      return Left(EntitlementLimitHelper.ledgerArchivingTierLocked());
    }

    return _ledgerRepository.unarchiveLedger(normalizedId);
  }
}
