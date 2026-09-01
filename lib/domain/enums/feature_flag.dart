/// Premium capabilities gated behind Pro or Pro+ tiers.
///
/// Import, backup, credit limits, and custom currencies are intentionally
/// excluded — they remain free for all tiers per the pricing matrix.
enum FeatureFlag {
  /// Merchant-branded PDF statement headers (Pro).
  brandedPdf,

  /// Archive Vault — user-archived ledger management (Pro).
  ledgerArchiving,

  /// Smart merge on restore with Arabic similarity matching (Pro).
  smartMerge,

  /// Multi-device sync across up to 10 devices (Pro+).
  ///
  /// Contest fork: permanently locked off via
  /// `AppConstants.kContestDisableMultiDeviceSync` — enum kept for entitlement maps.
  multiDeviceSync,

  /// Automated WhatsApp payment reminders (Pro+).
  whatsappAutomation,

  /// Debt aging, payment patterns, cash-flow analytics (Pro+).
  advancedAnalytics,

  /// Customer-facing balance portal links (Pro+).
  customerPortal,
}
