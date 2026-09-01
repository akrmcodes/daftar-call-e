import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CollectionsDeskRow row(String id, CollectionsDeskRowStatus status) {
    return CollectionsDeskRow(
      candidate: CollectionsCandidate(
        contactId: id,
        name: id,
        phone: '+96770000000$id',
        ledgerId: 'ledger',
        netBalance: -100,
        currencyCode: 'YER',
        ageDays: 12,
        toneBand: ReminderToneBand.reminder,
      ),
      body: 'body-$id',
      toneBand: ReminderToneBand.reminder,
      attachPdf: false,
      status: status,
    );
  }

  test('fromRows counts prepared, sent, failed, opened, and skipped', () {
    final metrics = CollectionsQueueMetrics.fromRows([
      row('a', CollectionsDeskRowStatus.opened),
      row('b', CollectionsDeskRowStatus.skipped),
      row('c', CollectionsDeskRowStatus.pending),
      row('d', CollectionsDeskRowStatus.sent),
      row('e', CollectionsDeskRowStatus.failed),
    ]);
    expect(
      metrics,
      const CollectionsQueueMetrics(
        prepared: 5,
        opened: 1,
        skipped: 1,
        sent: 1,
        failed: 1,
      ),
    );
  });
}
