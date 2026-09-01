import 'package:daftar/domain/constants/entitlement_limits.dart';
import 'package:daftar/domain/enums/app_tier.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'entitlement.freezed.dart';

/// Resolved subscription state: tier, workspace limits, and feature flags.
///
/// Serves as the single source of truth for monetization policy. Limits use
/// [EntitlementLimits.unlimited] (-1) for uncapped Pro/Pro+ workspace.
@freezed
abstract class Entitlement with _$Entitlement {
  const factory Entitlement({
    required AppTier tier,
    required Set<FeatureFlag> activeFeatures,
    required int maxLedgers,
    required int maxContacts,
    required int maxTransactions,
    DateTime? expiryDate,
  }) = _Entitlement;

  const Entitlement._();

  /// Free tier defaults: 1 ledger, 50 contacts, 500 transactions, no premium
  /// features.
  factory Entitlement.defaultFree() => const Entitlement(
    tier: AppTier.free,
    activeFeatures: {},
    maxLedgers: EntitlementLimits.freeMaxLedgers,
    maxContacts: EntitlementLimits.freeMaxContacts,
    maxTransactions: EntitlementLimits.freeMaxTransactions,
  );

  /// Pro tier with unlimited workspace and Pro feature flags.
  factory Entitlement.forPro({DateTime? expiryDate}) => Entitlement(
    tier: AppTier.pro,
    activeFeatures: _proFeatures,
    maxLedgers: EntitlementLimits.unlimited,
    maxContacts: EntitlementLimits.unlimited,
    maxTransactions: EntitlementLimits.unlimited,
    expiryDate: expiryDate,
  );

  /// Pro+ tier: Pro workspace plus Pro+ exclusive features.
  factory Entitlement.forProPlus({DateTime? expiryDate}) => Entitlement(
    tier: AppTier.proPlus,
    activeFeatures: _proPlusFeatures,
    maxLedgers: EntitlementLimits.unlimited,
    maxContacts: EntitlementLimits.unlimited,
    maxTransactions: EntitlementLimits.unlimited,
    expiryDate: expiryDate,
  );

  static const Set<FeatureFlag> _proFeatures = {
    FeatureFlag.brandedPdf,
    FeatureFlag.ledgerArchiving,
    FeatureFlag.smartMerge,
  };

  static const Set<FeatureFlag> _proPlusFeatures = {
    ..._proFeatures,
    FeatureFlag.multiDeviceSync,
    FeatureFlag.whatsappAutomation,
    FeatureFlag.advancedAnalytics,
    FeatureFlag.customerPortal,
  };

  /// Whether this entitlement has passed [expiryDate].
  bool get isExpired {
    final expiry = expiryDate;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(expiry.toUtc());
  }

  /// Whether [flag] is included in the active feature set.
  bool hasFeature(FeatureFlag flag) => activeFeatures.contains(flag);

  /// True when workspace cap is unlimited (Pro / Pro+).
  bool get hasUnlimitedLedgers => maxLedgers == EntitlementLimits.unlimited;

  bool get hasUnlimitedContacts => maxContacts == EntitlementLimits.unlimited;

  bool get hasUnlimitedTransactions =>
      maxTransactions == EntitlementLimits.unlimited;

  /// Whether another ledger can be created given [currentCount] live ledgers.
  bool canAddLedger(int currentCount) =>
      hasUnlimitedLedgers || currentCount < maxLedgers;

  /// Whether another contact can be created given [currentCount] live contacts.
  bool canAddContact(int currentCount) =>
      hasUnlimitedContacts || currentCount < maxContacts;

  /// Whether another transaction can be created given [currentCount] live txns.
  bool canAddTransaction(int currentCount) =>
      hasUnlimitedTransactions || currentCount < maxTransactions;

  /// Effective entitlement after expiry check — falls back to free tier.
  Entitlement get effective =>
      isExpired ? Entitlement.defaultFree() : this;
}
