import 'package:freezed_annotation/freezed_annotation.dart';

part 'encrypted_local_backup_snapshot.freezed.dart';

/// Result of creating an encrypted `.daftar` file on disk without persisting
/// metadata (used before a cloud upload step).
@freezed
abstract class EncryptedLocalBackupSnapshot with _$EncryptedLocalBackupSnapshot {
  const factory EncryptedLocalBackupSnapshot({
    required String filePath,
    required int sizeBytes,
    required String checksum,
    required DateTime createdAtUtc,
  }) = _EncryptedLocalBackupSnapshot;
}
