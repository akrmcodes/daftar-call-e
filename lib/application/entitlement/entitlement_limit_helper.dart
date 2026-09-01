import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/entitlement_limits.dart';
import 'package:daftar/domain/entities/entitlement.dart';

/// Builds limit failures from entitlement policy without referencing tier enums.
abstract final class EntitlementLimitHelper {
  static LimitExceededFailure ledgerLimit(Entitlement entitlement, int count) {
    return LimitExceededFailure(
      'Maximum number of ledgers reached.',
      featureKey: AppConstants.featureUnlimitedLedgers,
      currentCount: count,
      maxAllowed: _displayMax(entitlement.maxLedgers),
    );
  }

  static LimitExceededFailure contactLimit(Entitlement entitlement, int count) {
    return LimitExceededFailure(
      'Maximum number of contacts reached.',
      featureKey: AppConstants.featureUnlimitedContacts,
      currentCount: count,
      maxAllowed: _displayMax(entitlement.maxContacts),
    );
  }

  static LimitExceededFailure transactionLimit(
    Entitlement entitlement,
    int count,
  ) {
    return LimitExceededFailure(
      'Maximum number of transactions reached.',
      featureKey: AppConstants.featureUnlimitedTransactions,
      currentCount: count,
      maxAllowed: _displayMax(entitlement.maxTransactions),
    );
  }

  static LimitExceededFailure ledgerArchivingTierLocked() {
    return const LimitExceededFailure(
      'Ledger archiving requires a Pro subscription.',
      featureKey: AppConstants.featureLedgerArchiving,
      currentCount: 0,
      maxAllowed: 0,
      code: 'ledger_archiving_tier_locked',
    );
  }

  static int _displayMax(int policyMax) {
    if (policyMax == EntitlementLimits.unlimited) {
      return EntitlementLimits.freeMaxTransactions;
    }
    return policyMax;
  }
}
