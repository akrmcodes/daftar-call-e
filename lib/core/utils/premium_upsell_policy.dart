import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';

/// Decides whether a [LimitExceededFailure] should open the premium upsell.
abstract final class PremiumUpsellPolicy {
  /// Entitlement feature keys that warrant an upgrade prompt.
  static const Set<String> upsellFeatureKeys = {
    AppConstants.featureUnlimitedLedgers,
    AppConstants.featureUnlimitedContacts,
    AppConstants.featureUnlimitedTransactions,
    AppConstants.featureCloudBackup,
    AppConstants.featureCsvImport,
    AppConstants.featureCreditLimits,
    AppConstants.featureWhatsappAutomation,
    AppConstants.featureLedgerArchiving,
    AppConstants.featureMultiDeviceSync,
    'brandedPdf',
  };

  /// Returns true when [failure] represents a tier lock solvable by upgrade.
  static bool showsPremiumUpsell(LimitExceededFailure failure) {
    return upsellFeatureKeys.contains(failure.featureKey);
  }
}
