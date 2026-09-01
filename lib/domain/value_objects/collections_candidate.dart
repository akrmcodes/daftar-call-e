import 'package:daftar/domain/constants/reminder_tone_resolver.dart';
import 'package:daftar/domain/enums/payment_behavior_band.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:equatable/equatable.dart';

/// One overdue, email-reachable contact for the Stage 4 Collections Desk.
///
/// Amounts are integer minor units. [netBalance] is Drift truth
/// (`totalPayment - totalDebt`); they owe us when it is negative.
class CollectionsCandidate extends Equatable {
  /// Creates a Collections candidate.
  const CollectionsCandidate({
    required this.contactId,
    required this.name,
    required this.ledgerId,
    required this.netBalance,
    required this.currencyCode,
    required this.ageDays,
    required this.toneBand,
    this.phone,
    this.email,
    this.daysSinceLastPayment,
    this.daysSinceLastDebt,
  });

  /// Contact UUID.
  final String contactId;

  /// Display name from Drift.
  final String name;

  /// Optional phone (Hybrid E leftover / display).
  final String? phone;

  /// Optional email for SMTP send-batch.
  final String? email;

  /// Parent ledger UUID.
  final String ledgerId;

  /// Signed net (`totalPayment - totalDebt`). Negative = they owe us.
  final int netBalance;

  /// ISO currency for [netBalance].
  final String currencyCode;

  /// Calendar days from the as-of date to the oldest still-open debt slice.
  final int ageDays;

  /// Friendly / Reminder / Firm from aging (age base + recent-payer cap).
  final ReminderToneBand toneBand;

  /// Calendar days since the latest payment, or null if none.
  final int? daysSinceLastPayment;

  /// Calendar days since the latest debt, or null if none.
  final int? daysSinceLastDebt;

  /// Absolute outstanding when [netBalance] is negative.
  int get owedMinor => netBalance < 0 ? -netBalance : 0;

  /// Payment recency band derived from [daysSinceLastPayment].
  PaymentBehaviorBand get paymentBehaviorBand =>
      paymentBehaviorBandForLastPayment(daysSinceLastPayment);

  @override
  List<Object?> get props => [
        contactId,
        name,
        phone,
        email,
        ledgerId,
        netBalance,
        currencyCode,
        ageDays,
        toneBand,
        daysSinceLastPayment,
        daysSinceLastDebt,
      ];
}
