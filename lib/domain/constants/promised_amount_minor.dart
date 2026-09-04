/// Coerces CALL-E `promised_amount_minor` to an integer with no remainder.
///
/// Never stores `double`. JSON integers are accepted. Whole JSON numbers
/// (e.g. `1500.0`) convert. Any remainder → null (needs human).
abstract final class PromisedAmountMinor {
  /// Parses [raw] from JSON. `null` input is absence, not invalid.
  static int? tryParse(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is bool) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is double) {
      if (!raw.isFinite) {
        return null;
      }
      if (raw != raw.truncateToDouble()) {
        return null;
      }
      return raw.toInt();
    }
    return null;
  }

  /// True when [raw] was present but could not convert without remainder.
  static bool isInvalidPresent(Object? raw) {
    if (raw == null) {
      return false;
    }
    return tryParse(raw) == null;
  }
}
