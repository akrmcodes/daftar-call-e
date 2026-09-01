import 'package:daftar/application/backup/backup_queue_process_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupQueueProcessReport', () {
    test('merge combines flags with logical OR', () {
      const a = BackupQueueProcessReport(sawNeedsReauth: true);
      const b = BackupQueueProcessReport(
        sawQuotaExceeded: true,
        sawTransientNetworkFailure: true,
      );

      final merged = a.merge(b);

      expect(merged.sawNeedsReauth, isTrue);
      expect(merged.sawQuotaExceeded, isTrue);
      expect(merged.sawTransientNetworkFailure, isTrue);
    });
  });
}
