import 'package:equatable/equatable.dart';

/// Result of the device J.10 region + allowlist gate (Stage 2.2).
sealed class CallEligibility extends Equatable {
  const CallEligibility();
}

/// Blank or whitespace-only phone input.
class CallEmpty extends CallEligibility {
  const CallEmpty();

  @override
  List<Object?> get props => [];
}

/// Non-empty input that is not a valid CALL-E E.164.
class CallInvalid extends CallEligibility {
  const CallInvalid();

  @override
  List<Object?> get props => [];
}

/// YE, unknown prefix, unsupported ISO, or region/calling-code mismatch.
class CallUnavailable extends CallEligibility {
  const CallUnavailable();

  @override
  List<Object?> get props => [];
}

/// Valid J.10 pair but E.164 not on the injected allowlist.
class CallNotAllowlisted extends CallEligibility {
  /// Creates a not-allowlisted result.
  const CallNotAllowlisted({
    required this.e164,
    required this.region,
  });

  /// CALL-E `phones[]` value.
  final String e164;

  /// Declared ISO that passed the region gate.
  final String region;

  @override
  List<Object?> get props => [e164, region];
}

/// Eligible for the call rail (allowlist + region gate passed).
class CallEligible extends CallEligibility {
  /// Creates an eligible result.
  const CallEligible({
    required this.e164,
    required this.region,
  });

  /// CALL-E `phones[]` value.
  final String e164;

  /// ISO region to send on the J.9 recipient (`US`, `SA`, …).
  final String region;

  @override
  List<Object?> get props => [e164, region];
}
