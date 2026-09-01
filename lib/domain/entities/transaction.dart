import 'package:daftar/domain/entities/contact.dart' show Contact;
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

/// Represents a single financial transaction (debt or payment) for a contact.
///
/// Transactions are the core financial records. Each transaction belongs
/// to exactly one [Contact] via [contactId]. The [amount] is always stored
/// as an [int] in the smallest currency unit.
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [contactId]: FK to the parent contact.
/// - [type]: Whether this is a debt (عليه) or payment (له).
/// - [amount]: Amount in smallest currency unit (always positive).
/// - [currency]: ISO 4217 currency code (e.g., 'YER').
/// - [description]: Optional free-text description.
/// - [itemName]: Optional item name for smart autocomplete.
/// - [attachmentPath]: Optional file path to a receipt image or document.
/// - [transactionDate]: The date the transaction occurred (may differ from createdAt).
/// - [createdAt]: UTC timestamp of record creation.
/// - [updatedAt]: UTC timestamp of last modification.
/// - [isDeleted]: Soft-delete flag.
/// - [syncVersion]: Version counter for sync conflict resolution.
@freezed
abstract class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String contactId,
    required TransactionType type,
    required int amount,
    required String currency,
    required DateTime transactionDate, required DateTime createdAt, required DateTime updatedAt, String? description,
    String? itemName,
    String? attachmentPath,
    @Default(false) bool isDeleted,
    @Default(false) bool isArchived,
    @Default(0) int syncVersion,
  }) = _Transaction;
}
