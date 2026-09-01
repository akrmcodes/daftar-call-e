import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/auto_backup_notification_event.dart';
import 'package:daftar/domain/services/backup_notification_strings_resolver.dart';
import 'package:flutter/widgets.dart';

/// Resolves auto-backup notification strings from ARB localizations.
final class BackupAutoNotificationStrings
    implements BackupNotificationStringsResolver {
  const BackupAutoNotificationStrings();

  @override
  BackupNotificationCopy resolve(
    AutoBackupNotificationEvent event,
    String locale,
  ) {
    final l10n = lookupAppLocalizations(Locale(locale));
    return switch (event) {
      AutoBackupNotificationEvent.inProgress => (
          title: l10n.backupAutoNotifInProgressTitle,
          body: l10n.backupAutoNotifInProgressBody,
        ),
      AutoBackupNotificationEvent.success => (
          title: l10n.backupAutoNotifSuccessTitle,
          body: l10n.backupAutoNotifSuccessBody,
        ),
      AutoBackupNotificationEvent.willRetry => (
          title: l10n.backupAutoNotifRetryTitle,
          body: l10n.backupAutoNotifRetryBody,
        ),
      AutoBackupNotificationEvent.needsReauth => (
          title: l10n.backupAutoNotifNeedsReauthTitle,
          body: l10n.backupAutoNotifNeedsReauthBody,
        ),
      AutoBackupNotificationEvent.quotaExceeded => (
          title: l10n.backupAutoNotifQuotaTitle,
          body: l10n.backupAutoNotifQuotaBody,
        ),
      AutoBackupNotificationEvent.storageFull => (
          title: l10n.backupAutoNotifStorageFullTitle,
          body: l10n.backupAutoNotifStorageFullBody,
        ),
      AutoBackupNotificationEvent.failed => (
          title: l10n.backupAutoNotifFailedTitle,
          body: l10n.backupAutoNotifFailedBody,
        ),
    };
  }
}
