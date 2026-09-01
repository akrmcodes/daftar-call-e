/// Summary returned after `DemoStoreSeeder.seedData` — no email addresses.
class DemoSeedReport {
  const DemoSeedReport({
    required this.storeName,
    required this.storeNameKept,
    required this.locale,
    required this.ledgerName,
    required this.contactCount,
    required this.pdfCount,
    required this.textOnlyCount,
    required this.hasFriendlyTone,
    required this.hasReminderTone,
    required this.hasFirmTone,
  });

  /// Resolved store name after seeding.
  final String storeName;

  /// True when an existing non-empty store name was preserved.
  final bool storeNameKept;

  /// Locale used for generated labels (`ar` or `en`).
  final String locale;

  /// Customers ledger display name.
  final String ledgerName;

  /// Desk-eligible overdue contacts (always 7 for the sample store).
  final int contactCount;

  /// Ranked Top 5 statement PDF slots.
  final int pdfCount;

  /// Remaining send-set rows (text-only reminders).
  final int textOnlyCount;

  final bool hasFriendlyTone;
  final bool hasReminderTone;
  final bool hasFirmTone;
}
