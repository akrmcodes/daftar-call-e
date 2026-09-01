import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';

/// Spoken close-day report: today, Drive safety, desk outcome, seal.
///
/// Visuals carry currency totals, reminder/PDF policy, and opened. Never
/// claim Drive is saved unless [ClosingBackupStatus.uploaded].
String closingReportSpeakable({
  required AppLocalizations l10n,
  required ClosingRitualResult result,
}) {
  final beats = <String>[
    l10n.closingRitualReportTitle,
    l10n.closingRitualSpeakBooks(
      result.summary.debtCount,
      result.summary.paymentCount,
    ),
    _backupBeat(l10n, result.backupStatus),
  ];
  final metrics = result.queueMetrics;
  if (metrics != null) {
    beats.add(
      l10n.closingRitualSpeakQueue(
        metrics.prepared,
        metrics.sent,
        metrics.failed,
      ),
    );
  } else if (result.overdueCount > 0) {
    beats.add(l10n.closingRitualSpeakOverdueRemain(result.overdueCount));
  }
  beats.add(l10n.closingRitualSpeakClose);
  return beats.join('. ');
}

String _backupBeat(AppLocalizations l10n, ClosingBackupStatus status) {
  return switch (status) {
    ClosingBackupStatus.uploaded => l10n.closingRitualSpeakBackupSafe,
    ClosingBackupStatus.queued => l10n.closingRitualSpeakBackupQueued,
    ClosingBackupStatus.skippedUnsigned => l10n.closingRitualSpeakBackupUnsigned,
    ClosingBackupStatus.grantRequired => l10n.closingRitualSpeakBackupGrant,
    ClosingBackupStatus.failed => l10n.closingRitualSpeakBackupFailed,
  };
}
