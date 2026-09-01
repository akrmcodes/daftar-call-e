import 'dart:async';

import 'package:daftar/application/contact/check_credit_limit_use_case.dart';
import 'package:daftar/application/transaction/delete_transaction_use_case.dart';
import 'package:daftar/application/transaction/get_autocomplete_suggestions_use_case.dart';
import 'package:daftar/application/transaction/get_transactions_use_case.dart';
import 'package:daftar/application/transaction/restore_transaction_use_case.dart';
import 'package:daftar/application/transaction/update_transaction_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/providers/sync_mutation_trigger.dart';
import 'package:daftar/presentation/shared/currency_creation_policy.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_providers.g.dart';

/// Default number of transactions per page.
const int _pageSize = 20;

/// Minimum cooldown between load-more requests to prevent scroll spam.
const Duration _loadMoreCooldown = Duration(milliseconds: 300);

/// Streams the current page of transactions for a contact.
@riverpod
Stream<List<Transaction>> transactions(Ref ref, String contactId) {
  return ref
      .watch(getTransactionsUseCaseProvider)
      .execute(
        GetTransactionsParams(contactId: contactId),
      );
}

/// Manages the growing LIMIT for paginated transaction loading.
///
/// Each contact has an independent limit (keyed by [contactId]).
/// Starts at [_pageSize] (20) and increases by [_pageSize] on each
/// [loadMore] call, up to the total transaction count for the contact.
///
/// Includes debouncing ([_loadMoreCooldown]) to prevent rapid-fire
/// increments from a single scroll gesture.
@Riverpod(keepAlive: true)
class TransactionLimit extends _$TransactionLimit {
  DateTime _lastLoadMoreAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  int build(String contactId) => _pageSize;

  /// Increases the limit by [_pageSize] if more data is available.
  ///
  /// No-ops if:
  /// - Called within [_loadMoreCooldown] of the last call (debounce).
  /// - The current limit already covers all transactions (no more data).
  void loadMore({required int totalCount}) {
    // 1. Debounce: ignore if called too recently
    final now = DateTime.now();
    if (now.difference(_lastLoadMoreAt) < _loadMoreCooldown) {
      return;
    }

    // 2. Cap: don't exceed total available transactions
    if (state >= totalCount) {
      return;
    }

    // 3. Increment
    _lastLoadMoreAt = now;
    state = state + _pageSize;
  }
}

/// Streams paginated transactions using the growing limit.
///
/// Reads the current limit from [transactionLimitProvider] and passes
/// it to the use case. When the limit increases, this provider rebuilds
/// and the underlying Drift stream re-emits with more rows.
///
/// MUST be `keepAlive: true`. If autoDispose, a dependency change
/// (limit increment) destroys the old stream and creates a new one,
/// causing a frame of `AsyncLoading` with NO previous data — which
/// triggers the skeleton shimmer and annihilates scroll geometry.
/// With keepAlive, the provider is *reloaded* (previous data retained
/// via `AsyncValue.isRefreshing`) instead of *recreated*.
@Riverpod(keepAlive: true)
Stream<List<Transaction>> paginatedTransactions(
  Ref ref,
  String contactId,
) {
  final limit = ref.watch(transactionLimitProvider(contactId));
  return ref
      .watch(getTransactionsUseCaseProvider)
      .execute(
        GetTransactionsParams(contactId: contactId, limit: limit),
      );
}

/// Streams the total count of active transactions for a contact.
///
/// Backed by SQL `COUNT(*)` — ultra-lightweight, no row materialization.
/// Completely independent of pagination limits. Used for:
/// - Accurate transaction count display in `ContactListTile`
/// - Capping the [TransactionLimit] notifier to prevent over-fetching
@riverpod
Stream<int> transactionCount(Ref ref, String contactId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionCount(contactId);
}

/// Mutation controller for transaction CRUD operations.
@Riverpod(keepAlive: true)
class TransactionController extends _$TransactionController {
  @override
  FutureOr<void> build() {}

  /// Creates a transaction and updates the provider state.
  ///
  /// When the resulting credit state reaches warning or exceeded, this method
  /// also fires a best-effort local notification.
  Future<Either<Failure, TransactionWithCreditWarning>> addTransaction({
    required String contactId,
    required TransactionType type,
    required int amount,
    required String currency,
    String? description,
    String? itemName,
    String? attachmentPath,
    DateTime? transactionDate,
    String? warningNotificationTitle,
    String? warningNotificationBody,
    String? exceededNotificationBody,
  }) async {
    state = const AsyncValue.loading();

    try {
      final settings =
          ref.read(appSettingsProvider).value ?? const AppSettings();
      final resolvedCurrency =
          effectiveCreationCurrency(settings, currency);

      final result = await ref
          .read(addTransactionUseCaseProvider)
          .execute(
            contactId: contactId,
            type: type,
            amount: amount,
            currency: resolvedCurrency,
            description: description,
            itemName: itemName,
            attachmentPath: attachmentPath,
            transactionDate: transactionDate,
          );

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );

      final saveResult = result.getRight().toNullable();
      if (saveResult != null) {
        triggerSyncAfterLocalMutation(ref);
        unawaited(
          _showCreditWarningNotification(
            saveResult: saveResult,
            warningNotificationTitle: warningNotificationTitle,
            warningNotificationBody: warningNotificationBody,
            exceededNotificationBody: exceededNotificationBody,
          ),
        );
      }

      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to add transaction: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    }
  }

  /// Updates a transaction and refreshes the provider state.
  ///
  /// When the resulting credit state reaches warning or exceeded, this method
  /// also fires a best-effort local notification.
  Future<Either<Failure, TransactionWithCreditWarning>> updateTransaction({
    required String transactionId,
    required TransactionType type,
    required int amount,
    required String currency,
    String? description,
    String? itemName,
    String? attachmentPath,
    DateTime? transactionDate,
    String? warningNotificationTitle,
    String? warningNotificationBody,
    String? exceededNotificationBody,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await ref
          .read(updateTransactionUseCaseProvider)
          .execute(
            UpdateTransactionParams(
              id: transactionId,
              type: type,
              amount: amount,
              currency: currency,
              description: description,
              itemName: itemName,
              attachmentPath: attachmentPath,
              transactionDate: transactionDate,
            ),
          );

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );

      final saveResult = result.getRight().toNullable();
      if (saveResult != null) {
        triggerSyncAfterLocalMutation(ref);
        unawaited(
          _showCreditWarningNotification(
            saveResult: saveResult,
            warningNotificationTitle: warningNotificationTitle,
            warningNotificationBody: warningNotificationBody,
            exceededNotificationBody: exceededNotificationBody,
          ),
        );
      }

      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to update transaction: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    }
  }

  /// Soft-deletes a transaction and refreshes the provider state.
  Future<Either<Failure, Unit>> deleteTransaction(String transactionId) async {
    state = const AsyncValue.loading();

    try {
      final result = await ref
          .read(deleteTransactionUseCaseProvider)
          .execute(DeleteTransactionParams(id: transactionId));

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );
      if (result.isRight()) {
        triggerSyncAfterLocalMutation(ref);
      }
      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to delete transaction: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    }
  }

  /// Restores a soft-deleted transaction and refreshes the provider state.
  Future<Either<Failure, Unit>> restoreTransaction(String transactionId) async {
    state = const AsyncValue.loading();

    try {
      final result = await ref
          .read(restoreTransactionUseCaseProvider)
          .execute(RestoreTransactionParams(id: transactionId));

      state = result.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (_) => const AsyncValue.data(null),
      );
      if (result.isRight()) {
        triggerSyncAfterLocalMutation(ref);
      }
      return result;
    } on Object catch (error, stackTrace) {
      final failure = DatabaseFailure(
        'Failed to restore transaction: $error',
        code: 'database_error',
      );
      state = AsyncValue.error(failure, stackTrace);
      return Left(failure);
    }
  }

  Future<void> _showCreditWarningNotification({
    required TransactionWithCreditWarning saveResult,
    required String? warningNotificationTitle,
    required String? warningNotificationBody,
    required String? exceededNotificationBody,
  }) async {
    if (saveResult.warningLevel == CreditWarningLevel.none) {
      return;
    }

    final title = warningNotificationTitle?.trim();
    String? body;

    if (saveResult.warningLevel == CreditWarningLevel.warning) {
      body = warningNotificationBody?.trim();
    } else if (saveResult.warningLevel == CreditWarningLevel.exceeded) {
      body = exceededNotificationBody?.trim();
    }

    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return;
    }

    try {
      await ref
          .read(notificationServiceProvider)
          .showNotification(
            id: saveResult.transaction.contactId.hashCode,
            title: title,
            body: body,
            isUrgent: saveResult.warningLevel == CreditWarningLevel.exceeded,
          );
    } on Object {
      // Notification delivery is best-effort only.
    }
  }
}

/// Loads debounced autocomplete suggestions for transaction item names.
@riverpod
Future<Either<Failure, List<ItemSuggestion>>> autocompleteSuggestions(
  Ref ref,
  String query,
) async {
  final normalizedQuery = query.trim();
  if (normalizedQuery.length < 2) {
    return const Right(<ItemSuggestion>[]);
  }

  var didDispose = false;
  ref.onDispose(() => didDispose = true);

  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (didDispose) {
    throw Exception('Cancelled');
  }

  return ref
      .read(getAutocompleteSuggestionsUseCaseProvider)
      .execute(
        GetAutocompleteSuggestionsParams(query: normalizedQuery),
      );
}

/// Returns the most recent recorded amount for an item name.
@riverpod
Future<Either<Failure, int?>> recentPrice(Ref ref, String itemName) async {
  final normalizedItemName = itemName.trim();
  if (normalizedItemName.length < 2) {
    return const Right(null);
  }

  final suggestionsResult = await ref
      .read(getAutocompleteSuggestionsUseCaseProvider)
      .execute(
        GetAutocompleteSuggestionsParams(
          query: normalizedItemName,
          limit: 1,
        ),
      );

  return suggestionsResult.map((suggestions) {
    if (suggestions.isEmpty) {
      return null;
    }

    return suggestions.first.lastAmount;
  });
}
