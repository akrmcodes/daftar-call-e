import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/transaction.dart';
import 'package:daftar/domain/repositories/transaction_repository.dart';

/// Parameters for streaming a contact's transactions.
class GetTransactionsParams {
  /// Creates transaction query parameters.
  const GetTransactionsParams({
    required this.contactId,
    this.limit = AppConstants.defaultPageSize,
    this.offset = 0,
    this.startDate,
    this.endDate,
  });

  /// The contact whose transactions should be loaded.
  final String contactId;

  /// The maximum number of rows to return.
  final int limit;

  /// The number of rows to skip before taking results.
  final int offset;

  /// Optional inclusive start of the date filter.
  final DateTime? startDate;

  /// Optional inclusive end of the date filter.
  final DateTime? endDate;
}

/// Streams a contact's transactions with validation and pagination.
class GetTransactionsUseCase {
  /// Creates a use case that depends on the transaction repository contract.
  const GetTransactionsUseCase(this._transactionRepository);

  final TransactionRepository _transactionRepository;

  /// Validates the request and returns a reactive transaction stream.
  Stream<List<Transaction>> execute(GetTransactionsParams params) {
    final failure = _validate(params);
    if (failure != null) {
      return Stream<List<Transaction>>.error(failure);
    }

    return _transactionRepository.watchTransactions(
      params.contactId.trim(),
      limit: params.limit,
      offset: params.offset,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }

  Failure? _validate(GetTransactionsParams params) {
    final contactId = params.contactId.trim();
    if (contactId.isEmpty) {
      return const ValidationFailure(
        'Contact id is required.',
        code: 'transaction_contact_required',
      );
    }

    if (params.limit <= 0) {
      return const ValidationFailure(
        'Transaction limit must be greater than zero.',
        code: 'transaction_limit_invalid',
      );
    }

    if (params.offset < 0) {
      return const ValidationFailure(
        'Transaction offset cannot be negative.',
        code: 'transaction_offset_invalid',
      );
    }

    final startDate = params.startDate;
    final endDate = params.endDate;
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      return const ValidationFailure(
        'Start date must be before or equal to end date.',
        code: 'transaction_date_range_invalid',
      );
    }

    return null;
  }
}
