/// Dual-rail outreach assignment after Appendix D rank and eligibility caps.
enum OutreachRail {
  /// CALL-E call set only (≤5).
  call,

  /// Gmail SMTP send set only (≤20).
  email,

  /// In both call and email sets.
  both,

  /// Email only — phone is YE or unsupported for CALL-E.
  callUnavailable,

  /// No phone/email outreach channel.
  skipped,
}
