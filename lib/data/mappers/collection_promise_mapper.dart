import 'package:daftar/data/datasources/local/drift_database.dart' as db;
import 'package:daftar/domain/entities/collection_promise.dart' as domain;

/// Maps Drift `collection_promises` rows to domain entities.
extension CollectionPromiseRowMapper on db.CollectionPromise {
  /// Converts this row to a domain [domain.CollectionPromise].
  domain.CollectionPromise toDomain() {
    return domain.CollectionPromise(
      id: id,
      contactId: contactId,
      runId: runId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      promisedDate: promisedDate,
      status: status,
      updatedAt: updatedAt,
    );
  }
}
