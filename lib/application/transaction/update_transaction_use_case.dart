import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/ledger/ledger_archived_guard.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart'
    as transaction_repository;
import 'package:fpdart/fpdart.dart';

/// Parameters for updating an existing transaction.
class UpdateTransactionParams {
  /// Creates update parameters for a transaction.
  const UpdateTransactionParams({
    required this.id,
    this.type,
    this.amount,
    this.currency,
    String? description,
    this.itemName,
    this.attachmentPath,
    DateTime? transactionDate,
    @Deprecated('Use description instead.') String? notes,
    @Deprecated('Use transactionDate instead.') DateTime? date,
  }) : description = description ?? notes,
       transactionDate = transactionDate ?? date;

  /// The transaction identifier.
  final String id;

  /// The updated transaction type.
  final TransactionType? type;

  /// The updated amount in the smallest currency unit.
  final int? amount;

  /// The updated ISO 4217 currency code.
  final String? currency;

  /// Optional transaction description.
  final String? description;

  /// Optional item name for autocomplete.
  final String? itemName;

  /// Optional attachment path.
  final String? attachmentPath;

  /// The updated transaction date.
  final DateTime? transactionDate;
}

/// Updates a transaction and returns the post-save credit warning level.
class UpdateTransactionUseCase {
  /// Creates a use case that depends on the transaction and credit checker.
  const UpdateTransactionUseCase(
    this._transactionRepository,
    this._contactRepository,
    this._ledgerRepository,
    this._checkCreditLimitUseCase,
  );

  final transaction_repository.TransactionRepository _transactionRepository;
  final ContactRepository _contactRepository;
  final LedgerRepository _ledgerRepository;
  final CheckCreditLimitUseCase _checkCreditLimitUseCase;

  /// Validates the request, delegates the atomic update, and returns success.
  ///
  /// Any repository failure is propagated as a [Failure].
  Future<Either<Failure, TransactionWithCreditWarning>> execute(
    UpdateTransactionParams params,
  ) async {
    final normalizedId = params.id.trim();
    if (normalizedId.isEmpty) {
      return const Left(
        ValidationFailure(
          'Transaction id is required.',
          code: 'transaction_id_required',
        ),
      );
    }

    if (params.amount != null && params.amount! <= 0) {
      return Left(
        InvalidAmountFailure(
          'Transaction amount must be greater than zero.',
          amount: params.amount!,
          code: 'transaction_amount_invalid',
        ),
      );
    }

    final normalizedCurrency = params.currency?.trim().toUpperCase();
    if (normalizedCurrency != null && normalizedCurrency.isEmpty) {
      return const Left(
        ValidationFailure(
          'Transaction currency is required.',
          code: 'transaction_currency_required',
        ),
      );
    }

    try {
      final existingResult = await _transactionRepository.getById(normalizedId);
      if (existingResult.isLeft()) {
        return Left(existingResult.getLeft().toNullable()!);
      }

      final existingTransaction = existingResult.getRight().toNullable()!;
      final contactResult = await _contactRepository.getById(
        existingTransaction.contactId,
      );
      if (contactResult.isLeft()) {
        return Left(contactResult.getLeft().toNullable()!);
      }

      final ledgerResult = await _ledgerRepository.getById(
        contactResult.getRight().toNullable()!.ledgerId,
      );
      if (ledgerResult.isLeft()) {
        return Left(ledgerResult.getLeft().toNullable()!);
      }

      final archivedFailure = rejectIfUserArchived(
        ledgerResult.getRight().toNullable()!,
      );
      if (archivedFailure != null) {
        return Left(archivedFailure.getLeft().toNullable()!);
      }

      final updateResult = await _transactionRepository.update(
        transaction_repository.UpdateTransactionParams(
          id: normalizedId,
          amount: params.amount,
          type: params.type,
          currency: normalizedCurrency,
          description: _normalizeOptionalText(params.description),
          itemName: _normalizeOptionalText(params.itemName),
          attachmentPath: _normalizeOptionalText(params.attachmentPath),
          transactionDate: params.transactionDate?.toUtc(),
        ),
      );

      if (updateResult.isLeft()) {
        return Left(updateResult.getLeft().toNullable()!);
      }

      final updatedTransaction = updateResult.getRight().toNullable()!;
      final warningLevel = await _resolveCreditWarningLevel(
        updatedTransaction.contactId,
      );

      return Right((
        transaction: updatedTransaction,
        warningLevel: warningLevel,
      ));
    } on Object catch (error) {
      return Left(
        DatabaseFailure(
          'Failed to update transaction: $error',
          code: 'database_error',
        ),
      );
    }
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
