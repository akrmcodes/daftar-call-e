import 'package:daftar/domain/entities/transaction.dart' show Transaction;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'contact_balance.freezed.dart';

/// Denormalized balance record for a contact in a specific currency.
///
/// This entity provides O(1) balance lookups instead of aggregating
/// from raw transactions on every read. It is updated atomically
/// within the same Drift transaction that creates/modifies/deletes
/// a [Transaction].
///
/// Each contact may have multiple [ContactBalance] records — one per
/// currency in which they have transactions.
///
/// Fields:
/// - [contactId]: FK to the contact.
/// - [currencyCode]: ISO 4217 code for this balance's currency.
/// - [totalDebt]: Sum of all debt transaction amounts (smallest currency unit).
/// - [totalPayment]: Sum of all payment transaction amounts (smallest currency unit).
/// - [netBalance]: [totalPayment] - [totalDebt]. Positive = payments exceed debt.
/// - [lastUpdatedAt]: UTC timestamp when this balance was last recalculated.
@freezed
abstract class ContactBalance with _$ContactBalance {
  const factory ContactBalance({
    required String contactId,
    required String currencyCode,
    required int totalDebt,
    required int totalPayment,
    required int netBalance,
    required DateTime lastUpdatedAt,
  }) = _ContactBalance;
}
