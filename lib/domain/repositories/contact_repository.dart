import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/value_objects/collections_outreach_contact_entry.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';
import 'package:daftar/domain/value_objects/reminder_eligible_contact_entry.dart';
import 'package:daftar/domain/value_objects/voice_entity_resolution_entry.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for contact persistence operations.
///
/// Implementations must:
/// - Return [Left(DatabaseFailure)] for all persistence errors.
/// - Exclude soft-deleted records from query results by default.
/// - Append to `AuditLog` on every write operation.
/// - Use FTS5 for Arabic-normalized search queries.
abstract class ContactRepository {
  /// Streams all non-deleted contacts for a given [ledgerId],
  /// ordered by name.
  ///
  /// The stream auto-emits on any data change.
  Stream<List<Contact>> watchByLedger(String ledgerId);

  /// Streams the count of active contacts for a ledger.
  ///
  /// Uses SQL `COUNT(*)` — no row materialization. The stream auto-emits
  /// on any data change to the contacts table.
  Stream<int> watchContactCountByLedger(String ledgerId);

  /// Streams contact summaries for a ledger in a single JOIN query.
  ///
  /// Each emission includes contact identity, per-currency balances, and
  /// active transaction counts — replacing per-contact balance/count streams.
  Stream<List<ContactWithSummary>> watchContactSummariesByLedger(
    String ledgerId,
  );

  /// Returns all non-deleted contacts for a given [ledgerId].
  ///
  /// Results are ordered the same way as [watchByLedger].
  Future<Either<Failure, List<Contact>>> getByLedger(String ledgerId);

  /// Returns a contact by [id], or [Left(DatabaseFailure)] if not found.
  Future<Either<Failure, Contact>> getById(String id);

  /// Searches contacts by name using FTS5 Arabic-normalized full-text search.
  ///
  /// The [query] is normalized (diacritics stripped, Alef/Taa Marbuta
  /// normalized) before matching against the FTS5 index.
  ///
  /// Returns contacts across all ledgers matching the query.
  ///
  /// When [excludeUserArchivedLedgers] is true, contacts whose parent ledger
  /// is user-archived or import-archived are omitted (Quick Add flows).
  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    bool excludeUserArchivedLedgers = false,
  });

  Future<Either<Failure, List<VoiceEntityResolutionEntry>>>
  getVoiceEntityResolutionContext();

  Future<Either<Failure, List<ReminderEligibleContactEntry>>>
  getContactsEligibleForAutomatedReminders();

  /// Live-ledger contacts for dual-rail collections (no email required).
  Future<Either<Failure, List<CollectionsOutreachContactEntry>>>
  getContactsEligibleForCollectionsOutreach();

  /// Creates a new contact. Returns the created entity on success.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Contact>> create(CreateContactParams params);

  /// Updates an existing contact's mutable fields.
  ///
  /// Returns [Left(DatabaseFailure)] if the contact is not found or
  /// persistence fails.
  Future<Either<Failure, Contact>> update(UpdateContactParams params);

  /// Soft-deletes a contact by setting `isDeleted = true`.
  ///
  /// Implementations should cascade soft-delete to child transactions
  /// and update related balances within a single Drift transaction.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Unit>> delete(String id);

  /// Restores a soft-deleted contact by setting `isDeleted = false`.
  ///
  /// Implementations should restore the contact, all transactions for the
  /// same contact, and rebuild derived balance rows within a single Drift
  /// transaction.
  ///
  /// Returns [Left(DatabaseFailure)] if persistence fails.
  Future<Either<Failure, Contact>> restore(String id);

  /// Returns the count of active (non-deleted) contacts across all ledgers.
  ///
  /// Used for free-tier limit enforcement (max 50 contacts).
  /// Returns [Left(DatabaseFailure)] if the count query fails.
  Future<Either<Failure, int>> getActiveCount();

  /// Count of non-deleted archived contacts awaiting promotion.
  Future<Either<Failure, int>> getArchivedCount();

  /// Promotes up to [limit] archived contacts with live parent ledgers.
  Future<Either<Failure, int>> promoteArchived({required int limit});
}

/// Parameters for creating a new contact.
class CreateContactParams {
  const CreateContactParams({
    required this.ledgerId,
    required this.name,
    required this.avatarColor,
    this.phone,
    this.email,
    this.notes,
    this.creditLimit,
    this.creditCurrency,
    this.isArchived = false,
  });
  final String ledgerId;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final int? creditLimit;
  final String? creditCurrency;
  final String avatarColor;
  final bool isArchived;
}

/// Parameters for updating an existing contact.
class UpdateContactParams {
  const UpdateContactParams({
    required this.id,
    this.name,
    this.phone,
    this.email,
    this.updateEmail = false,
    this.notes,
    this.creditLimit,
    this.creditCurrency,
    this.doNotCall,
  });
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final bool updateEmail;
  final String? notes;
  final int? creditLimit;
  final String? creditCurrency;

  /// When null, the existing `doNotCall` flag is preserved.
  final bool? doNotCall;
}
