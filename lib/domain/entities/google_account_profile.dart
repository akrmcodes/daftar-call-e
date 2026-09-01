import 'package:freezed_annotation/freezed_annotation.dart';

part 'google_account_profile.freezed.dart';

/// Signed-in Google account details for presentation (no SDK types).
@freezed
abstract class GoogleAccountProfile with _$GoogleAccountProfile {
  const factory GoogleAccountProfile({
    required String id,
    required String email,
    String? displayName,
    String? photoUrl,
  }) = _GoogleAccountProfile;
}
