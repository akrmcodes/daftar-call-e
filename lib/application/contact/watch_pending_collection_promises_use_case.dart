import 'package:daftar/domain/entities/collection_promise.dart';
import 'package:daftar/domain/repositories/collection_call_repository.dart';

/// Streams pending display-only promises for one contact.
class WatchPendingCollectionPromisesUseCase {
  /// Creates the use case.
  const WatchPendingCollectionPromisesUseCase({
    required CollectionCallRepository collectionCallRepository,
  }) : _collectionCallRepository = collectionCallRepository;

  final CollectionCallRepository _collectionCallRepository;

  /// Live pending promises, newest [CollectionPromise.updatedAt] first.
  Stream<List<CollectionPromise>> execute(String contactId) {
    return _collectionCallRepository.watchPendingByContact(contactId);
  }
}
