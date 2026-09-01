import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Localized relative date for backup timestamps.
String formatBackupRelativeDate(AppLocalizations l10n, DateTime dt) {
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);

  if (diff.inMinutes < 1) {
    return l10n.backupRelativeJustNow;
  }
  if (diff.inHours < 1) {
    return l10n.backupRelativeMinutes(diff.inMinutes);
  }
  if (diff.inDays < 1) {
    return l10n.backupRelativeHours(diff.inHours);
  }
  if (diff.inDays == 1) {
    return l10n.backupRelativeYesterday;
  }
  if (diff.inDays < 7) {
    return l10n.backupRelativeDays(diff.inDays);
  }

  return DateFormat.yMMMd(AppConstants.numeralLocale).format(local);
}
