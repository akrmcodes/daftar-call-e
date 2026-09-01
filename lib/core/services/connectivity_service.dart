import 'package:connectivity_plus/connectivity_plus.dart';

/// Simplified connectivity for offline-first cloud sync UX.
enum ConnectivityStatus {
  online,
  offline,
}

/// Wraps [Connectivity] with a stable online/offline model.
class ConnectivityService {
  /// Creates a service with an optional injectable [Connectivity] instance.
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Emits the current status, then every connectivity change.
  Stream<ConnectivityStatus> watchStatus() async* {
    yield await currentStatus();
    yield* _connectivity.onConnectivityChanged.map(_mapResults);
  }

  /// One-shot connectivity probe.
  Future<ConnectivityStatus> currentStatus() async {
    final results = await _connectivity.checkConnectivity();
    return _mapResults(results);
  }

  ConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return ConnectivityStatus.offline;
    }
    final online = results.any((r) => r != ConnectivityResult.none);
    return online ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }
}
