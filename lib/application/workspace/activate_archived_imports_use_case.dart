import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/entitlement_limits.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Summary of archived rows promoted into the live workspace.
final class ActivateArchivedImportsResult {
  const ActivateArchivedImportsResult({
    required this.ledgersActivated,
    required this.contactsActivated,
    required this.transactionsActivated,
    required this.haltedByLimit,
  });

  final int ledgersActivated;
  final int contactsActivated;
  final int transactionsActivated;
  final bool haltedByLimit;

  int get totalActivated =>
      ledgersActivated + contactsActivated + transactionsActivated;
}

/// Promotes archive-first import rows into the live workspace after upgrade.
class ActivateArchivedImportsUseCase {
  const ActivateArchivedImportsUseCase(
    this._ledgerRepository,
    this._contactRepository,
    this._transactionRepository,
    this._activationRepository,
  );

  final LedgerRepository _ledgerRepository;
  final ContactRepository _contactRepository;
  final TransactionRepository _transactionRepository;
  final ActivationRepository _activationRepository;

  Future<Either<Failure, ActivateArchivedImportsResult>> execute() async {
    final entitlement = await _activationRepository.getEntitlement();

    final ledgerActiveEither = await _ledgerRepository.getActiveCount();
    if (ledgerActiveEither.isLeft()) {
      return Left(ledgerActiveEither.getLeft().toNullable()!);
    }
    final ledgerActive = ledgerActiveEither.getRight().toNullable()!;

    final contactActiveEither = await _contactRepository.getActiveCount();
    if (contactActiveEither.isLeft()) {
      return Left(contactActiveEither.getLeft().toNullable()!);
    }
    final contactActive = contactActiveEither.getRight().toNullable()!;

    final txnActiveEither = await _transactionRepository.getActiveCount();
    if (txnActiveEither.isLeft()) {
      return Left(txnActiveEither.getLeft().toNullable()!);
    }
    final txnActive = txnActiveEither.getRight().toNullable()!;

    final ledgerArchivedEither = await _ledgerRepository.getArchivedCount();
    if (ledgerArchivedEither.isLeft()) {
      return Left(ledgerArchivedEither.getLeft().toNullable()!);
    }
    final ledgerArchived = ledgerArchivedEither.getRight().toNullable()!;

    final contactArchivedEither = await _contactRepository.getArchivedCount();
    if (contactArchivedEither.isLeft()) {
      return Left(contactArchivedEither.getLeft().toNullable()!);
    }
    final contactArchived = contactArchivedEither.getRight().toNullable()!;

    final txnArchivedEither = await _transactionRepository.getArchivedCount();
    if (txnArchivedEither.isLeft()) {
      return Left(txnArchivedEither.getLeft().toNullable()!);
    }
    final txnArchived = txnArchivedEither.getRight().toNullable()!;

    var ledgersActivated = 0;
    var contactsActivated = 0;
    var transactionsActivated = 0;
    var halted = false;

    final ledgerSlots = _remainingSlots(
      entitlement.maxLedgers,
      ledgerActive,
      ledgerArchived,
    );
    if (ledgerSlots > 0) {
      final promoted = await _ledgerRepository.promoteArchived(limit: ledgerSlots);
      if (promoted.isLeft()) {
        return Left(promoted.getLeft().toNullable()!);
      }
      ledgersActivated = promoted.getRight().toNullable() ?? 0;
    }
    if (ledgerArchived > ledgersActivated &&
        !_isUnlimited(entitlement.maxLedgers)) {
      halted = true;
    }

    final contactSlots = _remainingSlots(
      entitlement.maxContacts,
      contactActive,
      contactArchived,
    );
    if (contactSlots > 0) {
      final promoted = await _contactRepository.promoteArchived(
        limit: contactSlots,
      );
      if (promoted.isLeft()) {
        return Left(promoted.getLeft().toNullable()!);
      }
      contactsActivated = promoted.getRight().toNullable() ?? 0;
    }
    if (contactArchived > contactsActivated &&
        !_isUnlimited(entitlement.maxContacts)) {
      halted = true;
    }

    final txnSlots = _remainingSlots(
      entitlement.maxTransactions,
      txnActive + transactionsActivated,
      txnArchived,
    );
    if (txnSlots > 0) {
      final promoted = await _transactionRepository.promoteArchived(
        limit: txnSlots,
      );
      if (promoted.isLeft()) {
        return Left(promoted.getLeft().toNullable()!);
      }
      transactionsActivated = promoted.getRight().toNullable() ?? 0;
    }
    if (txnArchived > transactionsActivated &&
        !_isUnlimited(entitlement.maxTransactions)) {
      halted = true;
    }

    return Right(
      ActivateArchivedImportsResult(
        ledgersActivated: ledgersActivated,
        contactsActivated: contactsActivated,
        transactionsActivated: transactionsActivated,
        haltedByLimit: halted,
      ),
    );
  }

  static int _remainingSlots(int maxPolicy, int active, int archivedWaiting) {
    if (_isUnlimited(maxPolicy)) {
      return archivedWaiting;
    }
    final remaining = maxPolicy - active;
    if (remaining <= 0) {
      return 0;
    }
    return remaining > archivedWaiting ? archivedWaiting : remaining;
  }

  static bool _isUnlimited(int maxPolicy) =>
      maxPolicy == EntitlementLimits.unlimited;
}
