import 'package:daftar/domain/entities/entitlement.dart';
import 'package:flutter/foundation.dart';

/// Development-only entitlement override for MVP builds.
///
/// When [forceProPlusInDevelopment] is true, `developmentProPlus()` is returned
/// from the activation repository so UI providers and application use cases
/// share the same tier. Remove or gate behind a flavor flag before production.
abstract final class DevEntitlement {
  /// Whether the app should behave as Pro+ without a stored activation token.
  static bool get forceProPlusInDevelopment => kDebugMode;

  /// Pro+ entitlement used for the development override.
  static Entitlement developmentProPlus() => Entitlement.forProPlus(
        expiryDate: DateTime.now().toUtc().add(const Duration(days: 365)),
      );
}
