/// Utility for formatting [DateTime] values into human-readable strings,
/// including Arabic relative dates and standard date/time formats.
///
/// All date operations use UTC internally. Numeric output always uses
/// Western Arabic numerals (0–9) per Khazna v3.
abstract final class DateUtil {
  // ── Arabic Day Names ──────────────────────────────────────────────────

  static const List<String> _arabicDayNames = [
    'الإثنين', // Monday
    'الثلاثاء', // Tuesday
    'الأربعاء', // Wednesday
    'الخميس', // Thursday
    'الجمعة', // Friday
    'السبت', // Saturday
    'الأحد', // Sunday
  ];

  // ── Arabic Month Names ────────────────────────────────────────────────

  static const List<String> _arabicMonthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// Returns a relative date string in Arabic.
  ///
  /// - Today: 'اليوم'
  /// - Yesterday: 'أمس'
  /// - 2–6 days ago: 'قبل 2 أيام', 'قبل 3 أيام', ...
  /// - 7+ days ago: formatted as 'dd/MM/yyyy'
  ///
  /// [date] is compared against [now] (defaults to `DateTime.now()`).
  static String relativeDate(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final difference = todayOnly.difference(dateOnly).inDays;

    if (difference == 0) return 'اليوم';
    if (difference == 1) return 'أمس';
    if (difference >= 2 && difference <= 6) {
      return 'قبل $difference أيام';
    }
    if (difference == 7) return 'قبل أسبوع';

    return formatDateArabic(date);
  }

  /// Formats a [DateTime] as `dd/MM/yyyy` using Western digits.
  ///
  /// Example: `2024-03-15` → `'15/03/2024'`
  static String formatDateArabic(DateTime date) {
    return formatDate(date);
  }

  /// Formats a [DateTime] as `dd/MM/yyyy` using Western digits.
  ///
  /// Example: `2024-03-15` → `'15/03/2024'`
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  /// Formats a [DateTime] as `dd MMM yyyy` using Arabic month names.
  ///
  /// Example: `2024-03-15` → `'15 مارس 2024'`
  static String formatDateLong(DateTime date) {
    final day = date.day.toString();
    final month = _arabicMonthNames[date.month - 1];
    final year = date.year.toString();
    return '$day $month $year';
  }

  /// Formats a [DateTime] time component as `HH:mm`.
  ///
  /// Example: `14:30` → `'14:30'`
  static String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Formats a [DateTime] time component as `HH:mm` in Western digits.
  ///
  /// Example: `14:30` → `'14:30'`
  static String formatTimeArabic(DateTime date) {
    return formatTime(date);
  }

  /// Returns the Arabic name for the day of the week.
  ///
  /// Monday = 1 in Dart's `DateTime.weekday`, matching index 0.
  static String arabicDayName(DateTime date) {
    return _arabicDayNames[date.weekday - 1];
  }
}
