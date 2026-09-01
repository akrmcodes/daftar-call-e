/// Whether to prepare collection reminders after close-the-day.
enum ClosingReminderPolicy {
  /// Send set: ranked overdue ∩ email, capped at 20.
  all,

  /// First five of the ranked shortlist (leftover prompt).
  top5,

  /// Skip reminders (skip-all).
  none,
}
