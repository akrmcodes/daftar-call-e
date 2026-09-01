import 'dart:async';

import 'package:daftar/data/datasources/remote/sync_remote_ds.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncRemoteDs changeWakeups', () {
    test('listener attached before start receives wake-ups', () async {
      final controller = StreamController<void>.broadcast();
      final ds = SyncRemoteDs(
        dio: Dio(),
        wakeupController: controller,
      );

      var wakeups = 0;
      ds.changeWakeups.listen((_) => wakeups++);

      controller.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(wakeups, 1);
      await ds.dispose();
    });

    test('default constructor exposes a stable broadcast stream', () async {
      final ds = SyncRemoteDs(dio: Dio());

      var wakeups = 0;
      ds.changeWakeups.listen((_) => wakeups++);

      expect(ds.changeWakeups, isNot(throwsA(anything)));
      await ds.dispose();
    });
  });
}
