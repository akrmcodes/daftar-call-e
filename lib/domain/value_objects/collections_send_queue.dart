import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:equatable/equatable.dart';

/// Persisted Hybrid E send queue so process death does not lose Sending i of N.
class CollectionsSendQueue extends Equatable {
  /// Creates a send-queue snapshot.
  const CollectionsSendQueue({
    required this.id,
    required this.status,
    required this.awaitingResume,
    required this.locale,
    required this.storeName,
    required this.ritual,
    required this.rows,
    required this.createdAt,
    required this.updatedAt,
    this.batchId,
  });

  /// UUID v4 primary key.
  final String id;

  /// Active, paused, or completed.
  final CollectionsSendQueueStatus status;

  /// True after a successful Open until the app returns from background.
  final bool awaitingResume;

  /// Draft locale (`ar` / `en`).
  final String locale;

  /// Store name baked into drafts.
  final String storeName;

  /// Ritual snapshot for the hero report after the queue finishes.
  final ClosingRitualResult ritual;

  /// Ranked desk rows (integer money on each candidate).
  final List<CollectionsDeskRow> rows;

  /// UTC insert time.
  final DateTime createdAt;

  /// UTC last mutation.
  final DateTime updatedAt;

  /// SMTP send-batch UUID. Null on Hybrid E leftover.
  final String? batchId;

  /// Copies this snapshot with selected fields replaced.
  CollectionsSendQueue copyWith({
    CollectionsSendQueueStatus? status,
    bool? awaitingResume,
    ClosingRitualResult? ritual,
    List<CollectionsDeskRow>? rows,
    DateTime? updatedAt,
    String? batchId,
  }) {
    return CollectionsSendQueue(
      id: id,
      status: status ?? this.status,
      awaitingResume: awaitingResume ?? this.awaitingResume,
      locale: locale,
      storeName: storeName,
      ritual: ritual ?? this.ritual,
      rows: rows ?? this.rows,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      batchId: batchId ?? this.batchId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    awaitingResume,
    locale,
    storeName,
    ritual,
    rows,
    createdAt,
    updatedAt,
    batchId,
  ];
}
