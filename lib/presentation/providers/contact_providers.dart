import 'dart:async';

import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/domain/value_objects/contact_with_summary.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_mutation_trigger.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'contact_providers.g.dart';

/// Streams contacts for the selected ledger.
@riverpod
Stream<List<Contact>> contacts(Ref ref, String ledgerId) {
  return ref.watch(getContactsUseCaseProvider).execute(ledgerId);
}

/// Tracks the current contact search query.
@Riverpod(keepAlive: true)
class ContactSearchQuery extends _$ContactSearchQuery {
  @override
  String build() => '';

  /// Updates the search query.
  void setQuery(String query) {
    state = query.trim();
  }

  /// Clears the search query.
  void clear() {
    state = '';
  }
}

/// Returns search results for the current query.
@riverpod
Future<Either<Failure, List<ContactSearchHit>>> contactSearchResults(
  Ref ref,
) async {
  final query = ref.watch(contactSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const Right(<ContactSearchHit>[]);
  }

  return ref.watch(searchContactsUseCaseProvider).execute(query);
}

/// Tracks the currently selected contact identifier.
@Riverpod(keepAlive: true)
class SelectedContactId extends _$SelectedContactId {
  @override
  String? build() => null;

  /// Updates the selected contact identifier.
  String? get contactId => state;

  /// Updates the selected contact identifier.
  set contactId(String? contactId) {
    state = contactId;
  }

  /// Clears the selected contact identifier.
  void clear() {
    state = null;
  }
}

/// Mutation controller for contact operations.
@Riverpod(keepAlive: true)
class ContactController extends _$ContactController {
  @override
  void build() {}

  /// Creates a new contact.
  Future<Either<Failure, Contact>> createContact({
    required String ledgerId,
    required String name,
    String? phone,
    String? email,
    String? notes,
    int? creditLimit,
    String? creditCurrency,
    String? avatarColor,
  }) async {
    final settings = ref.read(appSettingsProvider).value ?? const AppSettings();
    final resolvedCreditCurrency = creditCurrency == null
        ? null
        : effectiveCreationCurrency(settings, creditCurrency);

    final result = await ref
        .read(createContactUseCaseProvider)
        .execute(
          ledgerId: ledgerId,
          name: name,
          phone: phone,
          email: email,
          notes: notes,
          creditLimit: creditLimit,
          creditCurrency: resolvedCreditCurrency,
          avatarColor: avatarColor,
        );
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Updates an existing contact.
  Future<Either<Failure, Contact>> updateContact(Contact contact) async {
    final result =
        await ref.read(updateContactUseCaseProvider).execute(contact);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Soft-deletes a contact.
  Future<Either<Failure, Contact>> deleteContact(String contactId) async {
    final result =
        await ref.read(deleteContactUseCaseProvider).execute(contactId);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }

  /// Restores a soft-deleted contact and its transactions.
  Future<Either<Failure, Contact>> restoreContact(String contactId) async {
    final result =
        await ref.read(restoreContactUseCaseProvider).execute(contactId);
    result.fold((_) {}, (_) => triggerSyncAfterLocalMutation(ref));
    return result;
  }
}

@riverpod
Future<Either<Failure, Ledger>> ledgerById(Ref ref, String ledgerId) {
  return ref.watch(getLedgerByIdUseCaseProvider).execute(ledgerId);
}

@riverpod
Future<bool> isContactLedgerReadOnly(Ref ref, String contactId) async {
  final contactResult =
      await ref.watch(contactByIdProvider(contactId).future);
  final contact = contactResult.getRight().toNullable();
  if (contact == null) {
    return false;
  }

  final ledgerResult =
      await ref.watch(ledgerByIdProvider(contact.ledgerId).future);
  return ledgerResult.fold((_) => false, (ledger) => ledger.isUserArchived);
}

@riverpod
Future<bool> isLedgerReadOnly(Ref ref, String ledgerId) async {
  final result = await ref.watch(ledgerByIdProvider(ledgerId).future);
  return result.fold((_) => false, (ledger) => ledger.isUserArchived);
}

/// Streams the active contact count for a ledger via SQL `COUNT(*)`.
@riverpod
Stream<int> contactCount(Ref ref, String ledgerId) {
  return ref.watch(watchContactCountUseCaseProvider).execute(ledgerId);
}

/// Streams contact summaries (balances + txn counts) for a ledger.
@riverpod
Stream<List<ContactWithSummary>> contactSummariesByLedger(
  Ref ref,
  String ledgerId,
) {
  return ref.watch(getContactSummariesUseCaseProvider).execute(ledgerId);
}

/// O(1) lookup map keyed by contact id from [contactSummariesByLedgerProvider].
@riverpod
Map<String, ContactWithSummary> contactSummariesMap(
  Ref ref,
  String ledgerId,
) {
  final summaries =
      ref.watch(contactSummariesByLedgerProvider(ledgerId)).value ??
      const <ContactWithSummary>[];
  return {for (final summary in summaries) summary.contactId: summary};
}

/// Fetches a single contact by ID.
@riverpod
Future<Either<Failure, Contact>> contactById(Ref ref, String contactId) {
  return ref.watch(getContactByIdUseCaseProvider).execute(contactId);
}

/// Streams pending CALL-E promises for a contact (display-only).
@riverpod
Stream<List<CollectionPromise>> pendingCollectionPromises(
  Ref ref,
  String contactId,
) {
  return ref
      .watch(watchPendingCollectionPromisesUseCaseProvider)
      .execute(contactId);
}
