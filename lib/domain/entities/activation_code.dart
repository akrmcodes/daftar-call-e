import 'package:freezed_annotation/freezed_annotation.dart';

part 'activation_code.freezed.dart';

/// Represents a premium activation code and its validation status.
///
/// Activation codes are distributed as prepaid cards and unlock premium
/// features. Codes can be validated online (Supabase Edge Function) or
/// offline (format + checksum validation).
///
/// Fields:
/// - [id]: UUID v4 primary key.
/// - [code]: The activation code string (e.g., 'XXXX-XXXX-XXXX').
/// - [activatedAt]: UTC timestamp when the code was activated.
/// - [expiresAt]: UTC timestamp when the activation expires.
///   Null for lifetime activations.
/// - [tier]: Premium tier name (e.g., 'pro', 'business').
///   Determines which feature flags are unlocked.
@freezed
abstract class ActivationCode with _$ActivationCode {
  const factory ActivationCode({
    required String id,
    required String code,
    required DateTime activatedAt,
    required String tier, DateTime? expiresAt,
  }) = _ActivationCode;
}
