import 'dart:async' show unawaited;

import 'package:daftar/app/theme/app_dimensions.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/presentation/providers/auth_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_agent_taskmaster.dart';
import 'package:daftar/presentation/screens/closing_agent/widgets/closing_ritual_report_card.dart';
import 'package:daftar/presentation/shared/widgets/daftar_button.dart';
import 'package:daftar/presentation/shared/widgets/daftar_error_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

/// Close-the-day progress, report, and retry (SMTP lead).
class ClosingRitualPanel extends ConsumerWidget {
  /// Creates the ritual panel.
  const ClosingRitualPanel({
    required this.agentState,
    super.key,
  });

  /// Current Closing Agent state.
  final ClosingAgentState agentState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(closingAgentControllerProvider.notifier);
    final settings =
        ref.watch(appSettingsProvider).asData?.value ?? const AppSettings();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.pagePaddingH,
        0,
        AppDimensions.pagePaddingH,
        AppDimensions.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (agentState.phase == ClosingAgentPhase.ritualRunning)
            ClosingAgentTaskmaster(
              mode: agentState.ritualDeskPreflightPending
                  ? ClosingAgentTaskmasterMode.compact
                  : ClosingAgentTaskmasterMode.executing,
              localDay:
                  agentState.ritualTaskSummary?.localDay ??
                  agentState.ritualResult?.summary.localDay ??
                  ClosingAgentConstants.merchantLocalDay(),
              tasksDone: agentState.ritualTasksDone,
              tasksSkipped: agentState.ritualTasksSkipped,
              taskCurrent: agentState.ritualTaskCurrent,
              summary: agentState.ritualTaskSummary,
              overdueCount: agentState.ritualOverdueCount,
              backupStatus: agentState.ritualBackupStatus,
              backupFailed: agentState.ritualBackupFailed,
              deskBlocked: agentState.ritualDeskPreflightPending,
            ),
          if (agentState.ritualDeskPreflightPending) ...[
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.collectionsDeskSkipOutreach,
              variant: DaftarButtonVariant.tertiary,
              isExpanded: true,
              onPressed: () => unawaited(notifier.skipOutreach()),
            ),
          ],
          // Yes / Top 5 / PDF policy prompts are leftover Hybrid E. SMTP lead
          // opens the desk with `all` + `rankedTop5`. Keep the widgets and
          // [ClosingAgentController.chooseReminderPolicy] for leftover tests.
          if (agentState.phase == ClosingAgentPhase.ritualReport &&
              agentState.ritualResult != null) ...[
            ClosingAgentTaskmaster(
              mode: ClosingAgentTaskmasterMode.sealed,
              localDay: agentState.ritualResult!.summary.localDay,
              tasksDone: agentState.ritualTasksDone,
              tasksSkipped: agentState.ritualTasksSkipped,
            ),
            const Gap(AppDimensions.spacingMd),
            ClosingRitualReportCard(
              result: agentState.ritualResult!,
              ttsMuted: settings.ttsMuted,
              ttsLocale: agentState.resolvedSpeechLocale(settings.locale),
              onSignInToDrive:
                  agentState.ritualResult!.backupStatus ==
                      ClosingBackupStatus.skippedUnsigned
                  ? () => unawaited(_signInToDrive(context, ref))
                  : null,
              onGrantDrive:
                  agentState.ritualResult!.backupStatus ==
                      ClosingBackupStatus.grantRequired
                  ? () => unawaited(_grantDrive(context, ref))
                  : null,
            ),
          ],
          if (agentState.ritualRetryAvailable) ...[
            const Gap(AppDimensions.spacingMd),
            DaftarButton(
              label: l10n.closingRitualRetry,
              variant: DaftarButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => unawaited(notifier.retryClosingRitual()),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _signInToDrive(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(signInControllerProvider.notifier)
      .signInWithGoogle();
  if (!context.mounted) {
    return;
  }
  result.fold(
    (failure) {
      unawaited(DaftarErrorSheet.showForError(context, error: failure));
    },
    (_) {},
  );
}

Future<void> _grantDrive(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(driveOfflineGrantControllerProvider.notifier)
      .completeDriveAuthorization();
  if (!context.mounted) {
    return;
  }
  result.fold(
    (failure) {
      unawaited(DaftarErrorSheet.showForError(context, error: failure));
    },
    (_) {},
  );
}
