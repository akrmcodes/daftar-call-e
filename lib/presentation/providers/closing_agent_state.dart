import 'package:daftar/application/agent/ask_books_intent.dart';
import 'package:daftar/application/agent/speech_locale.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/domain/enums/call_batch_trigger.dart';
import 'package:daftar/domain/enums/call_run_outcome.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_task_id.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/closing_day_summary.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'closing_agent_state.freezed.dart';

/// Device-owned close-the-day state machine.
///
/// Ritual, desk rows, and SMTP `batchId` queues persist in Drift. Cloud Run
/// may scale to zero; in-memory ADK sessions are not the source of truth.
/// SMTP queues with a `batchId` are not Hybrid E hydrate (`wa.me` / sticky).
/// Architecture HUD overlay is §5.6 (`DaftarArchitectureHud`) — not this enum.
enum ClosingAgentPhase {
  /// Empty composer, no turn.
  idle,

  /// Cloud Run `/run` in progress.
  running,

  /// Proposals ready for review.
  ready,

  /// Close-the-day snapshot / backup / shortlist in progress.
  ritualRunning,

  /// Leftover Hybrid E Yes / Top 5 / PDF policy prompt (not the SMTP lead).
  ritualPrompt,

  /// Ranked Collections Desk (SMTP Approve & send).
  ritualDesk,

  /// Hero report card.
  ritualReport,
}

/// Which close-the-day prompt is on screen.
///
/// Leftover Hybrid E Yes / Top 5 / PDF policy. SMTP lead skips these and
/// opens the desk with `all` + `rankedTop5`.
enum ClosingRitualPromptKind {
  /// Yes / Top 5 / No.
  reminders,

  /// None / Selective / Selected.
  pdfs,
}

/// Composer mic banner (info fill — the one allowed lapis surface).
enum ClosingMicBannerKind {
  /// Short tap — hold-to-talk hint.
  holdHint,

  /// Microphone denied or permanently denied.
  permissionDenied,
}

/// Process-local Closing Agent UI state.
@freezed
abstract class ClosingAgentState with _$ClosingAgentState {
  const factory ClosingAgentState({
    @Default(ClosingAgentPhase.idle) ClosingAgentPhase phase,
    AgentTurnResult? turnResult,
    Failure? actionFailure,
    String? confirmingProposalId,
    @Default(<String>{}) Set<String> committedIds,
    @Default(<String>{}) Set<String> skippedIds,
    @Default(<String, String>{}) Map<String, String> ledgerIdByProposal,
    @Default(<String, String>{}) Map<String, String> currencyCodeByProposal,
    @Default(<String, String>{}) Map<String, String> contactIdByProposal,
    @Default(<String>{}) Set<String> createNewByProposal,
    @Default(<String, String>{}) Map<String, String> nameByProposal,
    @Default(<String, String>{}) Map<String, String> phoneByProposal,
    @Default(<String, String>{}) Map<String, String> ledgerNameByProposal,
    @Default(<String, int>{}) Map<String, int> amountMinorByProposal,
    @Default(<String, List<ContactSearchHit>>{})
    Map<String, List<ContactSearchHit>> candidatesByProposal,
    AskBooksAnswer? askAnswer,
    String? lastGoalText,
    String? lastAskContactId,
    AskBooksIntent? lastAskIntent,
    ClosingMicBannerKind? micBannerKind,
    @Default(false) bool contactsPermissionDenied,
    ClosingRitualResult? ritualResult,
    ClosingRitualPromptKind? ritualPromptKind,
    @Default(<ClosingTaskId>{}) Set<ClosingTaskId> ritualTasksDone,
    @Default(<ClosingTaskId>{}) Set<ClosingTaskId> ritualTasksSkipped,
    ClosingTaskId? ritualTaskCurrent,
    ClosingDaySummary? ritualTaskSummary,
    @Default(0) int ritualOverdueCount,
    @Default(false) bool ritualBackupFailed,
    ClosingBackupStatus? ritualBackupStatus,
    @Default(false) bool ritualDeskPreflightPending,
    @Default(false) bool ritualRetryAvailable,
    @Default(<CollectionsDeskRow>[]) List<CollectionsDeskRow> deskRows,
    @Default('ar') String deskLocale,
    @Default('Daftar') String deskStoreName,
    String? deskBusyContactId,
    String? queueId,
    CollectionsSendQueueStatus? queueStatus,
    @Default(false) bool queueAwaitingResume,
    DateTime? queueCreatedAt,
    @Default(false) bool collectionsDispatching,
    String? collectionsBatchId,
    @Default(false) bool callConsented,
    @Default(false) bool sendConsented,
    @Default(false) bool sendOutreachEnabled,
    @Default(false) bool pendingSendAfterCall,
    @Default(false) bool callRetryDismissed,
    CollectionsCallProgress? callProgress,
    String? speechLocaleOverride,
    @Default(CallBatchTrigger.closeDay) CallBatchTrigger callBatchTrigger,
    String? pendingCreditLimitPromptContactId,
  }) = _ClosingAgentState;

  const ClosingAgentState._();

  /// Chirp locale for this Closing Agent session (`ar` / `en`).
  ///
  /// Defaults to app settings. An explicit "speak Arabic/English" request
  /// overrides until the studio is popped. Does not change UI locale or RTL.
  String resolvedSpeechLocale(String settingsLocale) {
    return resolveSpeechLocale(
      settingsLocale: settingsLocale,
      override: speechLocaleOverride,
    );
  }

  /// Pending money/create proposals that still need a Confirm card.
  List<AgentProposal> get pendingConfirmable {
    final proposals = turnResult?.proposals ?? const <AgentProposal>[];
    return [
      for (final proposal in proposals)
        if (_isConfirmable(proposal.tool) &&
            !committedIds.contains(proposal.proposalId) &&
            !skippedIds.contains(proposal.proposalId))
          proposal,
    ];
  }

  /// Whether a money/create Confirm CTA should own the lapis glow.
  bool get hasPendingMoneyConfirm => pendingConfirmable.isNotEmpty;

  /// Pending closing-plan proposal, if any.
  AgentProposal? get pendingClosingPlan {
    final proposals = turnResult?.proposals ?? const <AgentProposal>[];
    for (final proposal in proposals) {
      if (proposal.tool == ProposalTool.proposeClosingPlan &&
          !committedIds.contains(proposal.proposalId) &&
          !skippedIds.contains(proposal.proposalId)) {
        return proposal;
      }
    }
    return null;
  }

  /// Whether Confirm, ritual prompt, Desk Start sending, or queue Open owns glow.
  bool get ownsPrimaryGlow =>
      hasPendingMoneyConfirm ||
      pendingClosingPlan != null ||
      (phase == ClosingAgentPhase.ritualPrompt && !hasPendingMoneyConfirm) ||
      (phase == ClosingAgentPhase.ritualDesk && !hasPendingMoneyConfirm);

  /// Leftover Hybrid E sticky bar only (`batchId` null). Never SMTP.
  bool get isQueueInFlight =>
      collectionsBatchId == null &&
      (queueStatus == CollectionsSendQueueStatus.active ||
          queueStatus == CollectionsSendQueueStatus.paused);

  /// First pending desk row, if any.
  CollectionsDeskRow? get firstPendingDeskRow {
    for (final row in deskRows) {
      if (row.status == CollectionsDeskRowStatus.pending) {
        return row;
      }
    }
    return null;
  }

  /// 1-based index for `Sending i of N`.
  int get queueSendingIndex {
    if (deskRows.isEmpty) {
      return 0;
    }
    var done = 0;
    for (final row in deskRows) {
      if (row.status != CollectionsDeskRowStatus.pending) {
        done += 1;
      }
    }
    if (done >= deskRows.length) {
      return deskRows.length;
    }
    return done + 1;
  }

  /// CALL-E call-set size from the ritual shortlist.
  int get deskCallCount => ritualResult?.callSet.length ?? 0;

  /// Email-rail size from the ritual shortlist.
  int get deskEmailCount => ritualResult?.emailRailShortlist.length ?? 0;

  /// Whether Confirm & Call should own the primary lapis glow.
  bool get callPrimaryOnDesk => deskCallCount > 0 && !callConsented;

  /// Contacts eligible for one HITL no-answer/voicemail retry.
  int get callRetryOfferCount {
    if (callRetryDismissed) {
      return 0;
    }
    final progress = callProgress;
    if (progress == null || !progress.isTerminal) {
      return 0;
    }
    var count = 0;
    for (final row in progress.results) {
      if (row.retryCount > 0) {
        continue;
      }
      if (row.status != CollectionsCallRowStatus.completed) {
        continue;
      }
      final outcome = row.outcome;
      if (outcome == CallRunOutcome.noAnswer ||
          outcome == CallRunOutcome.voicemail) {
        count += 1;
      }
    }
    return count;
  }

  /// B-trigger credit-limit call session (single contact, dedicated UI).
  bool get isCreditLimitCallSessionActive =>
      phase == ClosingAgentPhase.ritualDesk &&
      callBatchTrigger == CallBatchTrigger.creditLimit;

  /// Terminal when every call row is `completed` or `failed`.
  bool get creditLimitCallSessionTerminal =>
      callProgress?.isTerminal ?? false;

  /// Contact id for the active credit-limit session, if any.
  String? get creditLimitSessionContactId {
    if (!isCreditLimitCallSessionActive) {
      return null;
    }
    if (deskRows.isNotEmpty) {
      return deskRows.first.candidate.contactId;
    }
    final shortlist = ritualResult?.shortlist;
    if (shortlist != null && shortlist.isNotEmpty) {
      return shortlist.first.contactId;
    }
    return null;
  }

  static bool _isConfirmable(ProposalTool tool) {
    return tool == ProposalTool.proposeDebt ||
        tool == ProposalTool.proposePayment ||
        tool == ProposalTool.proposeCreateContact ||
        tool == ProposalTool.proposeCreateLedger ||
        tool == ProposalTool.proposeStatement;
  }
}
