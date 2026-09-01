import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/entities/activation_status.dart';
import 'package:daftar/domain/entities/entitlement.dart';
import 'package:daftar/domain/enums/feature_flag.dart';
import 'package:fpdart/fpdart.dart';

/// Contract for premium activation and the entitlement engine.
///
/// Activation codes are prepaid cards validated online (Edge Function) or
/// offline (format + checksum). The signed payload is stored in
/// platform secure storage — not in Drift.
abstract class ActivationRepository {
  /// Validates [code], persists the signed entitlement token, and returns the
  /// resolved [Entitlement].
  ///
  /// 1. Try online validation (server returns JWT-like signed payload).
  /// 2. On network failure, fall back to offline code format validation.
  /// 3. Store token in secure storage.
  Future<Either<Failure, Entitlement>> activate(String code);

  /// Reads and decodes the stored entitlement token.
  ///
  /// Returns [Entitlement.defaultFree] when missing, corrupt, or expired.
  Future<Entitlement> getEntitlement();

  /// Returns activation summary for plan-status screens, or `null` on free.
  Future<Either<Failure, ActivationStatus?>> getStatus();

  /// Whether [feature] is unlocked for the current effective entitlement.
  Future<bool> isFeatureUnlocked(FeatureFlag feature);

  /// Legacy string-key check for limit-style flags (e.g. `unlimitedLedgers`).
  Future<bool> isFeatureKeyUnlocked(String featureKey);
}
