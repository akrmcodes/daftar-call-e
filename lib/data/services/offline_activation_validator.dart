import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/domain/enums/app_tier.dart';

/// Placeholder offline activation code validation.
///
/// Replace [validateTier] with HMAC / RSA signature verification once the
/// backend code generator ships. Structure is intentionally isolated so the
/// crypto swap is a single-file change.
abstract final class OfflineActivationValidator {
  /// Returns the tier implied by [code], or `null` if format is invalid.
  static AppTier? validateTier(String code) {
    final normalized = code.trim().toUpperCase();

    if (normalized.startsWith(AppConstants.offlineProCodePrefix) &&
        normalized.length == AppConstants.offlineProCodeLength &&
        _checksumValid(normalized)) {
      return AppTier.pro;
    }

    if (normalized.startsWith(AppConstants.offlineProPlusCodePrefix) &&
        normalized.length == AppConstants.offlineProPlusCodeLength &&
        _checksumValid(normalized)) {
      return AppTier.proPlus;
    }

    return null;
  }

  /// Placeholder checksum: sum of code-unit values mod 97 equals 0.
  ///
  /// Real implementation will verify an embedded HMAC from the issuer.
  static bool _checksumValid(String code) {
    var sum = 0;
    for (final unit in code.codeUnits) {
      sum += unit;
    }
    return sum % 97 == 0;
  }
}
