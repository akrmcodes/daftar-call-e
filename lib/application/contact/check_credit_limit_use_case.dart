import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/repositories/balance_repository.dart';
import 'package:daftar/domain/repositories/contact_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Indicates how close a contact is to their credit limit.
enum CreditWarningLevel {
  /// No warning should be shown.
  none,

  /// The contact has reached the warning threshold.
  warning,

  /// The credit limit has been reached or exceeded.
  exceeded,
}

/// A transaction paired with its post-save credit warning level.
typedef TransactionWithCreditWarning = ({
  Transaction transaction,
  CreditWarningLevel warningLevel,
});

/// Checks a contact's balance against their configured credit limit.
class CheckCreditLimitUseCase {
  /// Creates a use case that depends on the contact and balance repositories.
  const CheckCreditLimitUseCase(
    this._contactRepository,
    this._balanceRepository,
  );

  final ContactRepository _contactRepository;
  final BalanceRepository _balanceRepository;

  /// Returns the applicable warning level for the contact.
  Future<Either<Failure, CreditWarningLevel>> execute(String contactId) async {
    final contactResult = await _contactRepository.getById(contactId);
    if (contactResult.isLeft()) {
      return Left(contactResult.getLeft().toNullable()!);
    }

    final contact = contactResult.getRight().toNullable()!;
    final creditLimit = contact.creditLimit;
    if (creditLimit == null || creditLimit <= 0) {
      return const Right(CreditWarningLevel.none);
    }

    final balancesResult = await _balanceRepository.getByContact(contactId);
    if (balancesResult.isLeft()) {
      return Left(balancesResult.getLeft().toNullable()!);
    }

    final balances = balancesResult.getRight().toNullable()!;
    return Right(
      _evaluateWarningLevel(
        contact.creditCurrency,
        creditLimit,
        balances,
      ),
    );
  }

  CreditWarningLevel _evaluateWarningLevel(
    String? creditCurrency,
    int creditLimit,
    List<ContactBalance> balances,
  ) {
    final relevantBalance = _selectRelevantBalance(balances, creditCurrency);
    if (relevantBalance == null) {
      return CreditWarningLevel.none;
    }

    final outstandingDebt = -relevantBalance.netBalance;
    if (outstandingDebt <= 0) {
      return CreditWarningLevel.none;
    }

    if (outstandingDebt >= creditLimit) {
      return CreditWarningLevel.exceeded;
    }

    final warningThreshold = creditLimit * AppConstants.limitWarningThreshold;
    if (outstandingDebt >= warningThreshold) {
      return CreditWarningLevel.warning;
    }

    return CreditWarningLevel.none;
  }

  ContactBalance? _selectRelevantBalance(
    List<ContactBalance> balances,
    String? creditCurrency,
  ) {
    if (balances.isEmpty) {
      return null;
    }

    if (creditCurrency != null && creditCurrency.trim().isNotEmpty) {
      final normalizedCurrency = creditCurrency.trim().toUpperCase();
      for (final balance in balances) {
        if (balance.currencyCode.toUpperCase() == normalizedCurrency) {
          return balance;
        }
      }

      return null;
    }

    var lowestBalance = balances.first;
    for (final balance in balances.skip(1)) {
      if (balance.netBalance < lowestBalance.netBalance) {
        lowestBalance = balance;
      }
    }

    return lowestBalance;
  }
}
