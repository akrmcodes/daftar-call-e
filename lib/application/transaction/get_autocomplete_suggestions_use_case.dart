import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/item_suggestion.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Parameters for loading autocomplete suggestions.
class GetAutocompleteSuggestionsParams {
  /// Creates suggestion parameters for an autocomplete query.
  const GetAutocompleteSuggestionsParams({
    required this.query,
    this.limit = 5,
  });

  /// The text to search for.
  final String query;

  /// Maximum number of suggestions to return.
  final int limit;
}

/// Loads recent item-name suggestions for the transaction entry UI.
class GetAutocompleteSuggestionsUseCase {
  /// Creates a use case that depends on the transaction repository contract.
  const GetAutocompleteSuggestionsUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Validates the query and returns matching item suggestions.
  ///
  /// Very short queries are ignored to avoid noisy broad matches.
  Future<Either<Failure, List<ItemSuggestion>>> execute(
    GetAutocompleteSuggestionsParams params,
  ) async {
    final normalizedQuery = params.query.trim();
    if (normalizedQuery.length < 2) {
      return const Right(<ItemSuggestion>[]);
    }

    if (params.limit <= 0) {
      return const Left(
        ValidationFailure(
          'Suggestion limit must be greater than zero.',
          code: 'autocomplete_limit_invalid',
        ),
      );
    }

    try {
      return await _transactionRepository.searchRecentItems(
        normalizedQuery,
        limit: params.limit,
      );
    } on Object catch (error) {
      return Left(
        DatabaseFailure(
          'Failed to load autocomplete suggestions: $error',
          code: 'database_error',
        ),
      );
    }
  }
}
