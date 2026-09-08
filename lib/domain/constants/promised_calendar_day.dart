/// Validates CALL-E `promised_date` as merchant calendar `YYYY-MM-DD`.
///
/// Matches Cloud Run [`agent/calls/get_map.py`] `_DATE_RE` plus real calendar
/// day check. Never stores ISO timestamps or free-text dates.
abstract final class PromisedCalendarDay {
  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses [raw] when present and valid. `null` input is absence, not invalid.
  static String? tryParse(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is! String) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = _pattern.firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return trimmed;
  }

  /// True when [raw] was present but could not parse to a calendar day.
  static bool isInvalidPresent(Object? raw) {
    if (raw == null) {
      return false;
    }
    if (raw is String && raw.trim().isEmpty) {
      return false;
    }
    return tryParse(raw) == null;
  }

  /// True when [value] is a validated `YYYY-MM-DD` string.
  static bool isValid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }
    return tryParse(value) != null;
  }
}
