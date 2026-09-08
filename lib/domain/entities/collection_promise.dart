import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:equatable/equatable.dart';

/// Display-only CALL-E promise for a contact card. Never ledger money.
class CollectionPromise extends Equatable {
  /// Creates a promise row.
  const CollectionPromise({
    required this.id,
    required this.contactId,
    required this.runId,
    required this.amountMinor,
    required this.currencyCode,
    required this.promisedDate,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String contactId;
  final String runId;
  final int amountMinor;
  final String currencyCode;

  /// Merchant calendar day `YYYY-MM-DD`.
  final String promisedDate;
  final CollectionPromiseStatus status;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        contactId,
        runId,
        amountMinor,
        currencyCode,
        promisedDate,
        status,
        updatedAt,
      ];
}
