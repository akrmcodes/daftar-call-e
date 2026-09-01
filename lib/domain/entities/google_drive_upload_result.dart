import 'package:freezed_annotation/freezed_annotation.dart';

part 'google_drive_upload_result.freezed.dart';

/// Outcome of uploading an encrypted backup to Google Drive.
@freezed
abstract class GoogleDriveUploadResult with _$GoogleDriveUploadResult {
  const factory GoogleDriveUploadResult({
    required String fileId,
    String? name,
    int? sizeBytes,
  }) = _GoogleDriveUploadResult;
}
