import 'dart:async';

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/presentation/providers/sync_engine_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Schedules a debounced sync cycle after a successful local mutation.
///
/// Contest quarantine: no-op when [AppConstants.kContestDisableMultiDeviceSync].
void triggerSyncAfterLocalMutation(Ref ref) {
  // Contest quarantine — Stage 8 disabled.
  if (AppConstants.kContestDisableMultiDeviceSync) {
    return;
  }
  unawaited(
    Future<void>.microtask(() {
      ref.read(syncEngineControllerProvider.notifier).requestSyncAfterLocalMutation();
    }),
  );
}
