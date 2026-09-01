/// Lifecycle of a Hybrid E WhatsApp send queue (Stage 4.3).
enum CollectionsSendQueueStatus {
  /// Merchant is working the queue; resume advances the offer.
  active,

  /// Auto-advance on resume is off. Open / Skip still work.
  paused,

  /// Every row is opened or skipped, or the merchant tapped Done.
  completed,
}
