/// Per-row Collections Desk status (Hybrid E leftover + SMTP lead path).
enum CollectionsDeskRowStatus {
  /// Not yet opened, skipped, or sent.
  pending,

  /// Merchant chose not to send this reminder.
  skipped,

  /// WhatsApp or statement share sheet was presented (Hybrid E leftover).
  opened,

  /// SMTP send-batch is in flight for this row.
  sending,

  /// SMTP `250` plus `Message-ID` (or idempotent skip with stored id).
  sent,

  /// Invalid email, PDF failure, or SMTP 5xx — not Hybrid E.
  failed,
}
