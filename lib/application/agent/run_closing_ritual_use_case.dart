import 'package:daftar/application/agent/get_closing_day_summary_use_case.dart';
import 'package:daftar/application/agent/map_closing_backup_status.dart';
import 'package:daftar/application/backup/upload_drive_backup_use_case.dart';
import 'package:daftar/application/contact/get_collections_candidates_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_ritual_step.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:fpdart/fpdart.dart';

/// Device-owned close-the-day: Drift snapshot → Drive → aged shortlist.
///
/// Does not wait on reminder/PDF prompts and never opens WhatsApp.
class RunClosingRitualUseCase {
  /// Creates the orchestrator.
  const RunClosingRitualUseCase({
    required GetClosingDaySummaryUseCase getClosingDaySummaryUseCase,
    required UploadDriveBackupUseCase uploadDriveBackupUseCase,
    required GetCollectionsCandidatesUseCase getCollectionsCandidatesUseCase,
  }) : _getClosingDaySummaryUseCase = getClosingDaySummaryUseCase,
       _uploadDriveBackupUseCase = uploadDriveBackupUseCase,
       _getCollectionsCandidatesUseCase = getCollectionsCandidatesUseCase;

  final GetClosingDaySummaryUseCase _getClosingDaySummaryUseCase;
  final UploadDriveBackupUseCase _uploadDriveBackupUseCase;
  final GetCollectionsCandidatesUseCase _getCollectionsCandidatesUseCase;

  /// Runs summary → backup → shortlist. Backup failures do not abort the close.
  Future<Either<Failure, ClosingRitualResult>> execute({
    String? localDay,
    DateTime? now,
    void Function(ClosingRitualStep step)? onStep,
    CalleDevicePolicy? devicePolicy,
  }) async {
    final policy = devicePolicy ?? CalleDevicePolicy.fromCompiled();
    final day = localDay ?? ClosingAgentConstants.merchantLocalDay(now);
    final summaryResult = await _getClosingDaySummaryUseCase.execute(
      localDay: day,
      now: now,
    );
    final summaryFailure = summaryResult.getLeft().toNullable();
    if (summaryFailure != null) {
      return Left(summaryFailure);
    }
    final summary = summaryResult.getRight().toNullable()!;
    onStep?.call(ClosingRitualStep.summary);

    final backupResult = await _uploadDriveBackupUseCase.call();
    final backupStatus = mapClosingBackupStatus(backupResult);
    onStep?.call(ClosingRitualStep.backup);

    final shortlistResult = await _getCollectionsCandidatesUseCase.execute(
      asOf: now,
      allowlist: policy.allowlist,
      allowlistRegion: policy.allowlistRegion,
    );
    final shortlistFailure = shortlistResult.getLeft().toNullable();
    if (shortlistFailure != null) {
      return Left(shortlistFailure);
    }
    final shortlist = shortlistResult.getRight().toNullable() ?? const [];
    onStep?.call(ClosingRitualStep.shortlist);

    return Right(
      ClosingRitualResult(
        summary: summary,
        backupStatus: backupStatus,
        shortlist: shortlist,
        needsHuman: backupStatus != ClosingBackupStatus.uploaded,
      ),
    );
  }
}
