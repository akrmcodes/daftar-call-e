import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:daftar/domain/repositories/collection_call_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Marks a display-only CALL-E promise kept, broken, or cancelled.
///
/// Never writes ledger money — payment remains add-transaction flow.
class UpdateCollectionPromiseStatusUseCase {
  /// Creates the use case.
  const UpdateCollectionPromiseStatusUseCase({
    required CollectionCallRepository collectionCallRepository,
  }) : _collectionCallRepository = collectionCallRepository;

  final CollectionCallRepository _collectionCallRepository;

  /// Persists [status] when the promise is currently pending.
  Future<Either<Failure, CollectionPromise>> execute({
    required String promiseId,
    required CollectionPromiseStatus status,
  }) {
    final normalizedId = promiseId.trim();
    if (normalizedId.isEmpty) {
      return Future.value(
        const Left(
          ValidationFailure(
            'Promise id is required.',
            code: 'promise_id_required',
          ),
        ),
      );
    }
    if (!status.isMerchantResolution) {
      return Future.value(
        const Left(
          ValidationFailure(
            'Promise status must be kept, broken, or cancelled.',
            code: 'promise_status_not_terminal',
          ),
        ),
      );
    }

    return _collectionCallRepository.updatePromiseStatus(
      promiseId: normalizedId,
      status: status,
    );
  }
}
