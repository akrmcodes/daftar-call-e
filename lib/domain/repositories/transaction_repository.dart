import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for transaction persistence operations.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Exclude soft-deleted records from query results by default.
/// - Update `ContactBalance` atomically within the same Drift transaction
///   on every write operation (create, update, delete).
/// - Append to `AuditLog` on every write operation.
abstract class TransactionRepository {
  /// Streams all non-deleted transactions for a given [contactId],
  /// ordered by `transactionDate` descending (newest first).
  ///
  /// The stream auto-emits on any data change.
  Stream<List<Transaction>> watchByContact(String contactId);

  /// Streams a paginated set of non-deleted transactions for a contact.
  ///
  /// Results are ordered by `transactionDate` descending, then
  /// `createdAt` descending. Optional [startDate] and [endDate] filters are
  /// applied inclusively before pagination.
  Stream<List<Transaction>> watchTransactions(
    String contactId, {
    int limit = 20,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Streams the count of active (non-deleted) transactions for a contact.
  ///
  /// This is a lightweight O(1) query backed by SQL `COUNT(*)`.
  /// Used to display accurate transaction counts in contact list tiles
  /// independent of pagination limits.
  ///
  /// The stream auto-emits on any data change to the transactions table.
  Stream<int> watchTransactionCount(String contactId);

  /// Returns all non-deleted transactions for a [contactId].
  ///
  /// Supports pagination via [limit] and [offset].
  Future<Either<Failure, List<Transaction>>> getByContact(
    String contactId, {
    int limit = 20,
    int offset = 0,
  });

  /// Returns transactions within a date range for a specific contact.
  ///
  /// Used for filtered views and PDF statement generation.
  Future<Either<Failure, List<Transaction>>> getByDateRange(
    String contactId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Live (non-deleted, non-archived) rows whose `createdAt` falls on [localDay]
  /// in the device timezone (Appendix J.4). Optional [now] is the clock used to
  /// format [localDay]; bounds are that calendar date, not `transactionDate`.
  Future<Either<Failure, List<Transaction>>> getCreatedOnLocalDay(
    String localDay, {
    DateTime? now,
  });

  /// Returns a transaction by [id], or [Left(DatabaseFailure)] if not found.
  Future<Either<Failure, Transaction>> getById(String id);

  /// Searches recent item names for autocomplete suggestions.
  ///
  /// Returns the most recent amount recorded for each matching item name.
  Future<Either<Failure, List<ItemSuggestion>>> searchRecentItems(
    String query, {
    int limit = 5,
  });

  /// Returns all active transactions for a contact without pagination.
  ///
  /// This is used for integrity verification and balance recalculation from
  /// scratch.
  Future<Either<Failure, List<Transaction>>> getRawTransactionsByContact(
    String contactId,
  );

  /// Creates a new transaction and atomically updates `ContactBalance`.
  ///
  /// Returns the created entity on success.
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Transaction>> create(CreateTransactionParams params);

  /// Updates an existing transaction and recalculates `ContactBalance`.
  ///
  /// Returns [Left(DatabaseFailure)] if the transaction is not found
  /// or persistence fails.
  Future<Either<Failure, Transaction>> update(UpdateTransactionParams params);

  /// Restores a previously soft-deleted transaction and recalculates balance.
  ///
  /// Returns [Left(DatabaseFailure)] if the transaction is not found
  /// or persistence fails.
  Future<Either<Failure, Unit>> restoreTransaction(String id);

  /// Soft-deletes a transaction and recalculates `ContactBalance`.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Unit>> deleteTransaction(String id);

  /// Returns the count of active (non-deleted) transactions across all contacts.
  ///
  /// Used for free-tier limit enforcement (max 500 transactions).
  /// Returns [Left(DatabaseFailure)] if the count query fails.
  Future<Either<Failure, int>> getActiveCount();

  /// Count of non-deleted archived transactions awaiting promotion.
  Future<Either<Failure, int>> getArchivedCount();

  /// Promotes up to [limit] archived transactions with live parent contacts.
  Future<Either<Failure, int>> promoteArchived({required int limit});
}

/// Parameters for creating a new transaction.
class CreateTransactionParams {
  const CreateTransactionParams({
    required this.contactId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    this.description,
    this.itemName,
    this.attachmentPath,
    this.isArchived = false,
  });
  final String contactId;
  final TransactionType type;
  final int amount;
  final String currency;
  final String? description;
  final String? itemName;
  final String? attachmentPath;
  final DateTime transactionDate;
  final bool isArchived;
}

/// Parameters for updating an existing transaction.
class UpdateTransactionParams {
  const UpdateTransactionParams({
    required this.id,
    this.type,
    this.amount,
    this.currency,
    this.description,
    this.itemName,
    this.attachmentPath,
    this.transactionDate,
  });
  final String id;
  final TransactionType? type;
  final int? amount;
  final String? currency;
  final String? description;
  final String? itemName;
  final String? attachmentPath;
  final DateTime? transactionDate;
}
