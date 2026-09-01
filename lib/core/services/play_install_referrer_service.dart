import 'dart:io';

import 'package:daftar/core/services/deferred_install_attribution_store.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

/// Reads the Android Play Install Referrer once per install (Stage 8.5).
///
/// iOS is a no-op — deferred attribution uses clipboard/manual fallback.
class PlayInstallReferrerService {
  /// Creates the service.
  PlayInstallReferrerService({
    DeferredInstallAttributionStore? attributionStore,
  }) : _attributionStore =
            attributionStore ?? DeferredInstallAttributionStore();

  final DeferredInstallAttributionStore _attributionStore;

  /// Queries Play Install Referrer and persists token via attribution store.
  Future<void> captureIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    try {
      final details = await PlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      if (referrer == null || referrer.isEmpty) {
        return;
      }
      await _attributionStore.captureFromReferrerString(referrer);
    } on Object catch (e, st) {
      debugPrint('PlayInstallReferrerService.captureIfNeeded failed: $e\n$st');
    }
  }
}
