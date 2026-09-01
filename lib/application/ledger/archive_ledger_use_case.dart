import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

class ArchiveLedgerUseCase {
  const ArchiveLedgerUseCase(
    this._ledgerRepository,
    this._contactRepository,
    this._transactionRepository,
    this._activationRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ContactRepository _contactRepository;
  final TransactionRepository _transactionRepository;
  final ActivationRepository _activationRepository;

  Future<Either<Failure, Ledger>> execute({
    required String ledgerId,
    ArchiveWithCarryForwardParams? carryForward,
  }) async {
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

    if (carryForward == null) {
      return _ledgerRepository.archiveLedger(normalizedId);
    }

    if (carryForward.sourceLedgerId != normalizedId) {
      return const Left(
        ValidationFailure(
          'Carry-forward source ledger does not match.',
          code: 'carry_forward_source_mismatch',
        ),
      );
    }

    final preflight = await _preflightCarryForward(carryForward);
    if (preflight.isLeft()) {
      return Left(preflight.getLeft().toNullable()!);
    }

    final carryForwardResult = await _ledgerRepository.archiveWithCarryForward(
      carryForward,
    );
    return carryForwardResult.fold(
      Left.new,
      (result) => Right(result.archivedLedger),
    );
  }

  Future<Either<Failure, Unit>> _preflightCarryForward(
    ArchiveWithCarryForwardParams params,
  ) async {
    if (params.sourceLedgerId == params.targetLedgerId) {
      return const Left(
        ValidationFailure(
          'Source and target ledger must differ.',
          code: 'carry_forward_same_ledger',
        ),
      );
    }

    final sourceResult = await _ledgerRepository.getById(params.sourceLedgerId);
    if (sourceResult.isLeft()) {
      return Left(sourceResult.getLeft().toNullable()!);
    }
    final source = sourceResult.getRight().toNullable()!;
    final sourceArchivedFailure = rejectIfUserArchived(source);
    if (sourceArchivedFailure != null) {
      return sourceArchivedFailure;
    }

    final targetResult = await _ledgerRepository.getById(params.targetLedgerId);
    if (targetResult.isLeft()) {
      return Left(targetResult.getLeft().toNullable()!);
    }
    final target = targetResult.getRight().toNullable()!;
    if (target.isUserArchived || target.isArchived) {
      return const Left(
        ValidationFailure(
          'Target ledger is not eligible for carry forward.',
          code: 'carry_forward_invalid_target',
        ),
      );
    }

    final previewResult = await _ledgerRepository.previewCarryForward(
      sourceLedgerId: params.sourceLedgerId,
      targetLedgerId: params.targetLedgerId,
    );
    if (previewResult.isLeft()) {
      return Left(previewResult.getLeft().toNullable()!);
    }
    final preview = previewResult.getRight().toNullable()!;

    if (preview.contactCount == 0) {
      return const Left(
        ValidationFailure(
          'No balances to carry forward.',
          code: 'no_balances_to_carry',
        ),
      );
    }

    final activeContactsResult = await _contactRepository.getActiveCount();
    final activeContacts = activeContactsResult.getRight().toNullable();
    if (activeContacts == null) {
      return Left(activeContactsResult.getLeft().toNullable()!);
    }

    final activeTransactionsResult =
        await _transactionRepository.getActiveCount();
    final activeTransactions =
        activeTransactionsResult.getRight().toNullable();
    if (activeTransactions == null) {
      return Left(activeTransactionsResult.getLeft().toNullable()!);
    }

    final entitlement =
        (await _activationRepository.getEntitlement()).effective;

    if (!entitlement.hasUnlimitedContacts) {
      final projectedContacts = activeContacts + preview.contactCount;
      if (projectedContacts > entitlement.maxContacts) {
        return Left(
          EntitlementLimitHelper.contactLimit(entitlement, projectedContacts),
        );
      }
    }

    if (!entitlement.hasUnlimitedTransactions) {
      final projectedTransactions =
          activeTransactions + preview.transactionCount;
      if (projectedTransactions > entitlement.maxTransactions) {
        return Left(
          EntitlementLimitHelper.transactionLimit(
            entitlement,
            projectedTransactions,
          ),
        );
      }
    }

    return const Right(unit);
  }
}
