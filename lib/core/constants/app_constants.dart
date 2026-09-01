/// Application-wide constants for the Daftar app.
///
/// These constants define free-tier resource limits, UI thresholds,
/// and default configuration values used across the application.
///
/// Free-tier limits are enforced in use cases (application layer).
/// Premium users bypass these limits via activation codes.
abstract final class AppConstants {
  // ── Free-Tier Limits ─────────────────────────────────────────────────

  /// Maximum number of active ledgers for free-tier users.
  static const int maxFreeLedgers = 1;

  /// Maximum number of active contacts (total, across all ledgers)
  /// for free-tier users.
  static const int maxFreeContacts = 50;

  /// Maximum number of active transactions (total, across all contacts)
  /// for free-tier users.
  static const int maxFreeTransactions = 500;

  // ── Device Storage ─────────────────────────────────────────────────────

  /// Minimum free device storage (MB) required before heavy I/O (backup, PDF).
  static const int minFreeStorageMegabytes = 50;

  // ── Warning Thresholds ───────────────────────────────────────────────

  /// Percentage threshold at which to display approaching-limit warnings.
  ///
  /// Example: At 80% of 50 contacts (40 contacts), show a warning.
  static const double limitWarningThreshold = 0.8;

  // ── PIN Security ─────────────────────────────────────────────────────

  /// Secure-storage key for the PIN salt (Base64-encoded random bytes).
  static const String pinSaltStorageKey = 'daftar_pin_salt';

  /// Secure-storage key for the PIN hash (Base64-encoded SHA-256 digest).
  static const String pinHashStorageKey = 'daftar_pin_hash';

  /// Secure-storage key for consecutive failed PIN attempt counter.
  static const String pinFailedAttemptsStorageKey = 'daftar_pin_failed_attempts';

  /// Sentinel stored in Drift pinHash column when a PIN is configured.
  ///
  /// The actual hash lives only in [pinHashStorageKey].
  static const String pinConfiguredMarker = 'configured';

  /// Random salt length in bytes (128-bit).
  static const int pinSaltLengthBytes = 16;

  /// Fixed PIN length (digits). UI and validation use this single value.
  static const int pinLength = 4;

  /// Minimum PIN length (digits). Same as [pinLength].
  static const int pinMinLength = pinLength;

  /// Maximum PIN length (digits). Same as [pinLength].
  static const int pinMaxLength = pinLength;

  /// Default auto-lock timeout when app lock is enabled (seconds).
  static const int defaultLockTimeoutSeconds = 60;

  /// Maximum consecutive failed PIN attempts before enforcing delay.
  static const int maxFailedPinAttempts = 5;

  // ── Localization / Numerals ──────────────────────────────────────────

  /// Locale tag for intl number and date formatting (Western digits).
  ///
  /// Always Western Arabic numerals (0–9) per Khazna v3 — even when UI is Arabic.
  static const String numeralLocale = 'en_US';

  // ── Pagination ───────────────────────────────────────────────────────

  /// Default page size for paginated list queries.
  static const int defaultPageSize = 20;

  // ── Undo ──────────────────────────────────────────────────────────────

  /// Duration of the undo window after a delete action (in seconds).
  static const int undoWindowSeconds = 30;

  // ── Premium Feature Keys ─────────────────────────────────────────────

  /// Feature key for unlimited ledgers.
  static const String featureUnlimitedLedgers = 'unlimitedLedgers';

  /// Feature key for unlimited contacts.
  static const String featureUnlimitedContacts = 'unlimitedContacts';

  /// Feature key for unlimited transactions.
  static const String featureUnlimitedTransactions = 'unlimitedTransactions';

  /// Feature key for cloud backup.
  static const String featureCloudBackup = 'cloudBackup';

  /// Feature key for CSV import.
  static const String featureCsvImport = 'csvImport';

  /// Feature key for credit limit enforcement.
  static const String featureCreditLimits = 'creditLimits';

  /// Feature key for WhatsApp automation.
  static const String featureWhatsappAutomation = 'whatsappAutomation';

  /// Feature key for ledger archiving (Archive Vault).
  static const String featureLedgerArchiving = 'ledgerArchiving';

  /// Feature key for Pro+ multi-device sync / team collaboration.
  static const String featureMultiDeviceSync = 'multiDeviceSync';

  /// Contest fork kill-switch: Stage 8 multi-device sync is quarantined.
  ///
  /// When `true`, sync engines never start, invite/deep-link bootstrap is
  /// skipped, unlock checks return false, and sync UI routes redirect away.
  /// Drive backup / Auth V2 are unaffected. See `docs/roadmap_v2.md` §0.4.
  static const bool kContestDisableMultiDeviceSync = true;

  /// Pro+ hard cap: owner + worker seats (seat_index 1–2).
  static const int maxWorkerSeats = 2;

  // ── Auth Session (Auth V2) ───────────────────────────────────────────

  /// Secure-storage key for the serialized `AuthSessionBundle` (schema v2).
  static const String authSessionStorageKey = 'daftar_auth_session_v2';

  /// Secure-storage key for the Supabase custom sync JWT bundle.
  ///
  /// Separate from [authSessionStorageKey] because the sync token lifecycle
  /// (1hr, Edge Function exchange) is independent of the Google OAuth session.
  static const String syncTokenStorageKey = 'daftar_sync_token';

  /// Secure-storage key for last-known workspace membership (Pro+ offline RBAC).
  ///
  /// Survives sync-token expiry so workers never escalate to owner locally.
  static const String syncMembershipStorageKey = 'daftar_sync_membership';

  /// Secure-storage key for the stable device UUID (audit + sync attribution).
  static const String deviceIdentityStorageKey = 'daftar_device_id';

  // ── Entitlement Engine ───────────────────────────────────────────────

  /// Secure-storage key for the signed entitlement JWT / token.
  static const String entitlementTokenStorageKey = 'daftar_entitlement_token';

  /// Offline Pro activation code prefix (placeholder checksum scheme).
  static const String offlineProCodePrefix = 'PRO-';

  /// Expected length of offline Pro codes (placeholder).
  static const int offlineProCodeLength = 16;

  /// Offline Pro+ activation code prefix (placeholder checksum scheme).
  static const String offlineProPlusCodePrefix = 'PROPLUS-';

  /// Expected length of offline Pro+ codes (placeholder).
  static const int offlineProPlusCodeLength = 24;

  // ── Support & Store Links ────────────────────────────────────────────

  /// WhatsApp support line (E.164 without +) for settings contact support.
  static const String supportWhatsAppPhone = '967771234567';

  /// Google Play listing for rate-app deep link.
  static const String playStoreListingUrl =
      'https://play.google.com/store/apps/details?id=com.akrmcodes.daftar';

  /// App Store listing for rate-app deep link (placeholder until App Store ID).
  static const String appStoreListingUrl =
      'https://apps.apple.com/app/daftar/id0000000000';

  // ── App Metadata ───────────────────────────────────────────────────────

  /// Human-readable app version shown in settings (sync with pubspec).
  static const String appVersionLabel = '0.1.0';
}
