import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact_balance.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for contact balance operations.
///
/// [ContactBalance] is a denormalized aggregate that provides O(1) balance
/// lookups. It is updated atomically within the same Drift transaction
/// as the underlying transaction write.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Maintain consistency with the raw transaction data.
abstract class BalanceRepository {
  /// Returns all balance records for a [contactId] (one per currency).
  ///
  /// Returns an empty list if the contact has no transactions.
  Future<Either<Failure, List<ContactBalance>>> getByContact(String contactId);

  /// Streams balance records for a [contactId], emitting on any change.
  ///
  /// Used by the presentation layer to reactively update balance displays.
  Stream<List<ContactBalance>> watchByContact(String contactId);

  /// Streams all balance records across contacts, emitting on any change.
  ///
  /// Used by the presentation layer for app-wide balance summaries.
  Stream<List<ContactBalance>> watchAllBalances();

  Stream<List<ContactBalance>> watchBalancesByLedger(String ledgerId);

  /// Fully recalculates the balance for a [contactId] from raw transactions.
  ///
  /// This is an integrity-verification operation. It re-aggregates all
  /// non-deleted transactions for the contact and replaces the existing
  /// [ContactBalance] records.
  ///
  /// Should be called:
  /// - After backup restore
  /// - On data integrity check
  /// - As a repair operation
  ///
  /// Returns [Left(DatabaseFailure)] if the operation fails.
  Future<Either<Failure, List<ContactBalance>>> recalculate(String contactId);
}
