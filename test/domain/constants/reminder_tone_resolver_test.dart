import 'package:daftar/domain/constants/reminder_tone_resolver.dart';
import 'package:daftar/domain/enums/payment_behavior_band.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reminderToneBandForAgeDays', () {
    test('friendly under 7, reminder from 7, firm from 30', () {
      expect(reminderToneBandForAgeDays(0), ReminderToneBand.friendly);
      expect(reminderToneBandForAgeDays(6), ReminderToneBand.friendly);
      expect(reminderToneBandForAgeDays(7), ReminderToneBand.reminder);
      expect(reminderToneBandForAgeDays(29), ReminderToneBand.reminder);
      expect(reminderToneBandForAgeDays(30), ReminderToneBand.firm);
      expect(reminderToneBandForAgeDays(40), ReminderToneBand.firm);
    });
  });

  group('paymentBehaviorBandForLastPayment', () {
    test('none, recent at 14, lapsed after 14', () {
      expect(
        paymentBehaviorBandForLastPayment(null),
        PaymentBehaviorBand.none,
      );
      expect(paymentBehaviorBandForLastPayment(0), PaymentBehaviorBand.recent);
      expect(paymentBehaviorBandForLastPayment(14), PaymentBehaviorBand.recent);
      expect(paymentBehaviorBandForLastPayment(15), PaymentBehaviorBand.lapsed);
    });
  });

  group('reminderToneBandForAging', () {
    test('age 40 and last pay 3 is reminder not firm', () {
      expect(
        reminderToneBandForAging(ageDays: 40, daysSinceLastPayment: 3),
        ReminderToneBand.reminder,
      );
    });

    test('age 40 and last pay 14 is reminder', () {
      expect(
        reminderToneBandForAging(ageDays: 40, daysSinceLastPayment: 14),
        ReminderToneBand.reminder,
      );
    });

    test('age 40 and last pay 60 stays firm', () {
      expect(
        reminderToneBandForAging(ageDays: 40, daysSinceLastPayment: 60),
        ReminderToneBand.firm,
      );
    });

    test('age 40 and no payment stays firm', () {
      expect(
        reminderToneBandForAging(ageDays: 40),
        ReminderToneBand.firm,
      );
    });

    test('age 5 and no payment stays friendly', () {
      expect(
        reminderToneBandForAging(ageDays: 5),
        ReminderToneBand.friendly,
      );
    });

    test('age 20 and no payment stays reminder', () {
      expect(
        reminderToneBandForAging(ageDays: 20),
        ReminderToneBand.reminder,
      );
    });
  });
}
