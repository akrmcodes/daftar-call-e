/// Collections reminder tone from aging signals (Appendix C / Stage 4.4).
///
/// Age base (Appendix D, Stage 3.2 lock):
/// - [friendly]: ageDays under 7
/// - [reminder]: ageDays under 30
/// - [firm]: ageDays 30 or more
///
/// Adaptive cap: a payment within 14 local days never yields [firm].
/// No shame language. Never promotes a softer band.
enum ReminderToneBand {
  /// Recent outstanding debt (under 7 local days).
  friendly,

  /// Mid-age outstanding debt (7–29 local days).
  reminder,

  /// Long-outstanding debt (30 local days or more).
  firm,
}
