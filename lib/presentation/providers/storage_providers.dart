import 'package:daftar/core/services/storage_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storage_providers.g.dart';

/// Shared device storage probe for backup and export flows.
@Riverpod(keepAlive: true)
StorageService storageService(Ref ref) {
  return StorageService();
}
