import 'dart:async';
import 'dart:developer' as developer;

import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/services/crash_logger_service.dart';
import 'package:disk_space_plus/disk_space_plus.dart';

/// Probes device free storage before heavy local I/O (backup, PDF export).
class StorageService {
  /// Creates a [StorageService] with an optional [DiskSpacePlus] for tests.
  StorageService({DiskSpacePlus? diskSpacePlus})
    : _diskSpacePlus = diskSpacePlus ?? DiskSpacePlus();

  final DiskSpacePlus _diskSpacePlus;

  /// Returns whether at least [minMegabytes] of free space is available.
  ///
  /// On platform-channel failure (unsupported platform, plugin bug), returns
  /// `true` so backups are not permanently blocked — the error is logged.
  Future<bool> hasEnoughSpace({
    int minMegabytes = AppConstants.minFreeStorageMegabytes,
  }) async {
    try {
      final freeMegabytes = await _diskSpacePlus.getFreeDiskSpace;
      if (freeMegabytes == null) {
        developer.log(
          'StorageService: free disk space unavailable (null); assuming sufficient',
          name: 'daftar.storage',
        );
        return true;
      }

      return freeMegabytes >= minMegabytes;
    } on Object catch (error, stackTrace) {
      developer.log(
        'StorageService: disk space probe failed; assuming sufficient',
        error: error,
        stackTrace: stackTrace,
        name: 'daftar.storage',
      );
      unawaited(
        CrashLogger.recordError(
          error,
          stackTrace,
          reason: 'disk_space_probe_failed',
        ),
      );
      return true;
    }
  }
}
