import 'package:daftar/core/l10n/generated/app_localizations.dart';

/// Formats backup file size using localized ARB keys.
String formatBackupSize(AppLocalizations l10n, int bytes) {
  if (bytes < 1024) {
    return l10n.backupSizeBytes(bytes);
  }
  if (bytes < 1024 * 1024) {
    return l10n.backupSizeKb((bytes / 1024).toStringAsFixed(1));
  }
  return l10n.backupSizeMb((bytes / (1024 * 1024)).toStringAsFixed(1));
}

/// Sums total bytes across backup metadata list.
int sumBackupBytes(Iterable<int> sizes) => sizes.fold(0, (a, b) => a + b);
