/// How recently this currency slice has received a payment.
///
/// Used by Stage 4.4 adaptive tone. Never shown as a shame label.
enum PaymentBehaviorBand {
  /// Last payment in this currency was within 14 local days.
  recent,

  /// Has paid before, but not in the last 14 local days.
  lapsed,

  /// No payments in this currency slice.
  none,
}
