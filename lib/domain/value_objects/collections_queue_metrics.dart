import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:equatable/equatable.dart';

/// Prepared / sent / failed / skipped counts for the close-the-day report.
class CollectionsQueueMetrics extends Equatable {
  /// Creates queue metrics.
  const CollectionsQueueMetrics({
    required this.prepared,
    required this.opened,
    required this.skipped,
    this.sent = 0,
    this.failed = 0,
  });

  /// Totals from a desk snapshot (pending/sending count as neither sent nor skipped).
  factory CollectionsQueueMetrics.fromRows(List<CollectionsDeskRow> rows) {
    var opened = 0;
    var skipped = 0;
    var sent = 0;
    var failed = 0;
    for (final row in rows) {
      switch (row.status) {
        case CollectionsDeskRowStatus.opened:
          opened += 1;
        case CollectionsDeskRowStatus.skipped:
          skipped += 1;
        case CollectionsDeskRowStatus.sent:
          sent += 1;
        case CollectionsDeskRowStatus.failed:
          failed += 1;
        case CollectionsDeskRowStatus.pending:
        case CollectionsDeskRowStatus.sending:
          break;
      }
    }
    return CollectionsQueueMetrics(
      prepared: rows.length,
      opened: opened,
      skipped: skipped,
      sent: sent,
      failed: failed,
    );
  }

  /// How many drafts were on the Desk when sending started.
  final int prepared;

  /// Rows whose WhatsApp or statement share sheet was presented (Hybrid E leftover).
  ///
  /// Opened is not sent.
  final int opened;

  /// Rows the merchant skipped (including Skip outreach leftover).
  final int skipped;

  /// SMTP `250` plus Message-ID (or idempotent skip treated as sent).
  final int sent;

  /// Invalid email, PDF failure, or SMTP 5xx.
  final int failed;

  @override
  List<Object?> get props => [prepared, opened, skipped, sent, failed];
}
