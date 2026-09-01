import 'package:daftar/domain/enums/payment_behavior_band.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';

/// Appendix D age base: friendly under 7, reminder under 30, else firm.
ReminderToneBand reminderToneBandForAgeDays(int ageDays) {
  if (ageDays < 7) {
    return ReminderToneBand.friendly;
  }
  if (ageDays < 30) {
    return ReminderToneBand.reminder;
  }
  return ReminderToneBand.firm;
}

/// Payment-behavior band from last-payment recency (Stage 4.4).
PaymentBehaviorBand paymentBehaviorBandForLastPayment(
  int? daysSinceLastPayment,
) {
  if (daysSinceLastPayment == null) {
    return PaymentBehaviorBand.none;
  }
  if (daysSinceLastPayment <= 14) {
    return PaymentBehaviorBand.recent;
  }
  return PaymentBehaviorBand.lapsed;
}

/// Adaptive tone: age base, then cap firm to reminder for a recent payer.
///
/// Never promotes a softer band. Last-debt recency is not a tone input.
ReminderToneBand reminderToneBandForAging({
  required int ageDays,
  int? daysSinceLastPayment,
}) {
  final base = reminderToneBandForAgeDays(ageDays);
  final behavior = paymentBehaviorBandForLastPayment(daysSinceLastPayment);
  if (behavior == PaymentBehaviorBand.recent &&
      base == ReminderToneBand.firm) {
    return ReminderToneBand.reminder;
  }
  return base;
}
