import 'package:daftar/core/services/connectivity_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_providers.g.dart';

/// Shared connectivity probe for sync and UI.
@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) {
  return ConnectivityService();
}

/// Reactive online/offline stream for the app shell.
@Riverpod(keepAlive: true)
Stream<ConnectivityStatus> connectivityStatus(Ref ref) {
  return ref.watch(connectivityServiceProvider).watchStatus();
}
