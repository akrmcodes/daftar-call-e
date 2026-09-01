import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/entitlement/entitlement_limit_helper.dart';
import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/activation_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Creates a transaction, updates balances atomically, and returns warnings.
class AddTransactionUseCase {
  /// Creates a use case that depends on transaction persistence and credit
  /// limit evaluation.
  const AddTransactionUseCase(
    this._transactionRepository,
    this._contactRepository,
    this._ledgerRepository,
    this._checkCreditLimitUseCase,
    this._activationRepository,
  );

  final TransactionRepository _transactionRepository;
  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;
  final CheckCreditLimitUseCase _checkCreditLimitUseCase;
  final ActivationRepository _activationRepository;

  /// Validates the input, enforces the free-tier limit, and stores a new
  /// transaction.
  ///
  /// Returns the created transaction and its credit warning level on success.
  Future<Either<Failure, TransactionWithCreditWarning>> execute({
    required String contactId,
    required TransactionType type,
    required int amount,
    required String currency,
    String? description,
    String? itemName,
    String? attachmentPath,
    DateTime? transactionDate,
    bool saveAsArchived = false,
  }) async {
    final normalizedContactId = contactId.trim();
    if (normalizedContactId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Contact id is required.',
          code: 'transaction_contact_required',
        ),
      );
    }

    if (amount <= 0) {
      return Left(
        InvalidAmountFailure(
          'Transaction amount must be greater than zero.',
          amount: amount,
          code: 'transaction_amount_invalid',
        ),
      );
    }

    final normalizedCurrency = currency.trim().toUpperCase();
    if (normalizedCurrency.isEmpty) {
      return const Left(
        ValidationFailure(
          'Transaction currency is required.',
          code: 'transaction_currency_required',
        ),
      );
    }

    final contactResult = await _contactRepository.getById(normalizedContactId);
    if (contactResult.isLeft()) {
      return Left(contactResult.getLeft().toNullable()!);
    }

    final contact = contactResult.getRight().toNullable()!;
    final ledgerResult = await _ledgerRepository.getById(contact.ledgerId);
    if (ledgerResult.isLeft()) {
      return Left(ledgerResult.getLeft().toNullable()!);
    }

    final archivedFailure = rejectIfUserArchived(
      ledgerResult.getRight().toNullable()!,
    );
    if (archivedFailure != null) {
      return Left(archivedFailure.getLeft().toNullable()!);
    }

    final activeCountResult = await _transactionRepository.getActiveCount();
    final activeCount = activeCountResult.getRight().toNullable();
    if (activeCount == null) {
      return Left(activeCountResult.getLeft().toNullable()!);
    }

    if (!saveAsArchived) {
      final entitlement = await _activationRepository.getEntitlement();
      if (!entitlement.canAddTransaction(activeCount)) {
        return Left(
          EntitlementLimitHelper.transactionLimit(entitlement, activeCount),
        );
      }
    }

    final createdTransactionResult = await _transactionRepository.create(
      CreateTransactionParams(
        contactId: normalizedContactId,
        type: type,
        amount: amount,
        currency: normalizedCurrency,
        description: _normalizeOptionalText(description),
        itemName: _normalizeOptionalText(itemName),
        attachmentPath: _normalizeOptionalText(attachmentPath),
        transactionDate: (transactionDate ?? DateTime.now()).toUtc(),
        isArchived: saveAsArchived,
      ),
    );

    if (createdTransactionResult.isLeft()) {
      return Left(createdTransactionResult.getLeft().toNullable()!);
    }

    final createdTransaction = createdTransactionResult
        .getRight()
        .toNullable()!;
    final warningLevel = await _resolveCreditWarningLevel(
      createdTransaction.contactId,
    );

    return Right((
      transaction: createdTransaction,
      warningLevel: warningLevel,
    ));
  }

  Future<CreditWarningLevel> _resolveCreditWarningLevel(
    String contactId,
  ) async {
    try {
      final result = await _checkCreditLimitUseCase.execute(contactId);
      return result.getRight().toNullable() ?? CreditWarningLevel.none;
    } on Object {
      return CreditWarningLevel.none;
    }
  }

  static String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
