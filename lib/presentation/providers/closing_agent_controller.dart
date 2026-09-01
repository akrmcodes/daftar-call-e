import 'dart:async';

import 'package:daftar/application/agent/answer_ask_books_use_case.dart';
import 'package:daftar/application/agent/ask_books_intent.dart';
import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:daftar/application/agent/correct_spoken_amount_minor.dart';
import 'package:daftar/application/agent/extract_statement_contact_hint.dart';
import 'package:daftar/application/agent/group_capture_proposals.dart';
import 'package:daftar/application/agent/map_closing_backup_status.dart';
import 'package:daftar/application/agent/speech_locale.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/services/connectivity_service.dart';
import 'package:daftar/core/utils/agent_speech.dart';
import 'package:daftar/core/utils/haptic_service.dart';
import 'package:daftar/core/utils/native_contact_picker_service.dart';
import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/contact.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/closing_backup_status.dart';
import 'package:daftar/domain/enums/closing_pdf_policy.dart';
import 'package:daftar/domain/enums/closing_reminder_policy.dart';
import 'package:daftar/domain/enums/closing_task_id.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/collections_send_queue_status.dart';
import 'package:daftar/domain/enums/confirm_proposal_status.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/closing_ritual_result.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/domain/value_objects/collections_queue_metrics.dart';
import 'package:daftar/domain/value_objects/collections_send_queue.dart';
import 'package:daftar/domain/value_objects/contact_search_hit.dart';
import 'package:daftar/presentation/providers/backup_providers.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/closing_ritual_providers.dart';
import 'package:daftar/presentation/providers/connectivity_providers.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'closing_agent_controller.g.dart';

const NetworkFailure _agentUnreachable = NetworkFailure(
  'Closing Agent unreachable.',
  code: 'closing_agent_request_failed',
);

const NetworkFailure _whatsAppOpenFailed = NetworkFailure(
  'WhatsApp could not be opened.',
  code: 'whatsapp_open_failed',
);

/// Riverpod notifier for Closing Agent turns. Calls use cases only.
@Riverpod(keepAlive: true)
class ClosingAgentController extends _$ClosingAgentController {
  bool _buildingDesk = false;
  bool _sendOutreach = false;
  bool _autoDispatchOutreach = true;
  Timer? _holdHintDismissTimer;

  static const Duration holdHintVisible = Duration(milliseconds: 2800);

  /// Ritual row pulse delay (zero in widget tests to avoid timer bleed).
  @visibleForTesting
  static Duration ritualPulseDelay = const Duration(milliseconds: 120);

  /// Stagger between honest summary/shortlist reveals.
  @visibleForTesting
  static Duration ritualStaggerDelay = const Duration(milliseconds: 140);

  @override
  ClosingAgentState build() {
    final useCase = ref.watch(synthesizeAgentSpeechUseCaseProvider);
    final connectivity = ref.watch(connectivityServiceProvider);
    AgentSpeech.bind(
      synthesize: useCase.execute,
      isOnline: () async {
        final status = await connectivity.currentStatus();
        return status == ConnectivityStatus.online;
      },
    );
    ref.onDispose(() {
      _holdHintDismissTimer?.cancel();
      AgentSpeech.unbind();
    });
    return const ClosingAgentState();
  }

  /// Sends [goalText] to Cloud Run and stores parsed proposals.
  Future<void> submitGoal(String goalText) {
    return _submitTurn(goalText: goalText);
  }

  /// Sends a hold-to-talk WAV clip. Skips the local ask short-circuit.
  Future<void> submitVoice(AgentAudioClip clip) {
    return _submitTurn(
      goalText: '',
      audioClip: clip,
      skipLocalAsk: true,
    );
  }

  Future<void> _submitTurn({
    required String goalText,
    AgentAudioClip? audioClip,
    bool skipLocalAsk = false,
  }) async {
    final priorContactId = state.lastAskContactId;
    final priorIntent = state.lastAskIntent;
    final previousQueueId = state.queueId;
    unawaited(AgentSpeech.stop());
    _applySpeechLocaleFrom(goalText);
    _clearMicBanner();
    state = state.copyWith(
      phase: ClosingAgentPhase.running,
      actionFailure: null,
      askAnswer: null,
      lastGoalText: goalText,
      candidatesByProposal: const {},
      contactIdByProposal: const {},
      createNewByProposal: const {},
      nameByProposal: const {},
      phoneByProposal: const {},
      ledgerNameByProposal: const {},
      amountMinorByProposal: const {},
      committedIds: const {},
      skippedIds: const {},
      ledgerIdByProposal: const {},
      currencyCodeByProposal: const {},
      ritualResult: null,
      ritualPromptKind: null,
      ritualTasksDone: const {},
      ritualTasksSkipped: const {},
      ritualTaskCurrent: null,
      ritualTaskSummary: null,
      ritualOverdueCount: 0,
      ritualBackupFailed: false,
      ritualBackupStatus: null,
      ritualDeskPreflightPending: false,
      ritualRetryAvailable: false,
      deskRows: const [],
      deskLocale: 'ar',
      deskStoreName: 'Daftar',
      deskBusyContactId: null,
      queueId: null,
      queueStatus: null,
      queueAwaitingResume: false,
      queueCreatedAt: null,
    );
    if (previousQueueId != null) {
      unawaited(
        ref
            .read(completeCollectionsSendQueueUseCaseProvider)
            .execute(previousQueueId),
      );
    }

    if (!skipLocalAsk && AnswerAskBooksUseCase.looksLikeAsk(goalText)) {
      final askIntent = classifyAsk(goalText);
      final askResult = await ref
          .read(answerAskBooksUseCaseProvider)
          .execute(
            goalText: goalText,
            lastContactId: priorContactId,
          );
      final askFailure = askResult.getLeft().toNullable();
      if (askFailure != null) {
        state = state.copyWith(
          phase: ClosingAgentPhase.idle,
          actionFailure: askFailure,
        );
        return;
      }
      final askAnswer = askResult.getRight().toNullable();
      if (askAnswer != null) {
        state = state.copyWith(
          phase: ClosingAgentPhase.ready,
          turnResult: null,
          askAnswer: askAnswer,
          actionFailure: null,
          lastAskIntent: askIntent,
          lastAskContactId: _contactIdFromAsk(askAnswer) ?? priorContactId,
        );
        return;
      }
    }

    final radio = await ref.read(connectivityServiceProvider).currentStatus();
    if (radio == ConnectivityStatus.offline) {
      _failCloudCall(null, _agentUnreachable);
      return;
    }

    final tokenResult = await ref
        .read(hydrateAgentIdTokenUseCaseProvider)
        .execute();
    final tokenFailure = tokenResult.getLeft().toNullable();
    if (tokenFailure != null) {
      _failCloudCall(null, tokenFailure);
      return;
    }

    final result = await ref
        .read(runClosingAgentTurnUseCaseProvider)
        .execute(goalText: goalText, audioClip: audioClip);
    final runFailure = result.getLeft().toNullable();
    if (runFailure != null) {
      _failCloudCall(null, runFailure);
      return;
    }

    final turn = result.getRight().toNullable()!;
    final snapSource = audioClip != null
        ? (turn.narrative?.trim().isNotEmpty == true
              ? turn.narrative!.trim()
              : goalText)
        : goalText;
    final loaded = await _loadCandidates(turn, snapSource);
    final askAnswer = await _askFromParseGoal(snapSource, turn);
    _applySpeechLocaleFrom(snapSource);
    state = ClosingAgentState(
      phase: ClosingAgentPhase.ready,
      turnResult: turn,
      askAnswer: askAnswer,
      lastGoalText: snapSource,
      lastAskIntent: classifyAsk(snapSource) ?? priorIntent,
      lastAskContactId: _contactIdFromAsk(askAnswer) ?? priorContactId,
      candidatesByProposal: loaded.candidates,
      contactIdByProposal: loaded.ids,
      amountMinorByProposal: _spokenAmounts(turn, snapSource),
      actionFailure: loaded.failure,
      speechLocaleOverride: state.speechLocaleOverride,
    );
    _speakNarrative(turn.narrative);
  }

  /// Drops a session speech-language override when the studio is popped.
  void resetSpeechSession() {
    if (state.speechLocaleOverride == null) {
      return;
    }
    state = state.copyWith(speechLocaleOverride: null);
  }

  void _applySpeechLocaleFrom(String transcript) {
    final switched = detectSpeechLocaleSwitch(transcript);
    if (switched == null) {
      return;
    }
    state = state.copyWith(speechLocaleOverride: switched);
  }

  String _speechLocale(AppSettings settings) {
    return state.resolvedSpeechLocale(settings.locale);
  }

  void _speakNarrative(String? narrative) {
    if (state.pendingConfirmable.isNotEmpty || state.askAnswer != null) {
      return;
    }
    final settings =
        ref.read(appSettingsProvider).asData?.value ?? const AppSettings();
    if (settings.ttsMuted) {
      return;
    }
    final locale = _speechLocale(settings);
    if (state.pendingClosingPlan != null) {
      unawaited(HapticService.light());
      final l10n = lookupAppLocalizations(
        Locale(normalizeSpeechLocale(locale)),
      );
      unawaited(AgentSpeech.speak(l10n.closingAgentSpeakPlanReady, locale: locale));
      return;
    }
    final text = narrative?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    unawaited(AgentSpeech.speak(text, locale: locale));
  }

  /// Marks a Confirm card busy before a statement PDF generate+share.
  void beginConfirming(String proposalId) {
    if (state.confirmingProposalId != null) {
      return;
    }
    state = state.copyWith(
      confirmingProposalId: proposalId,
      actionFailure: null,
    );
  }

  /// Clears Confirm busy state after a failed generate/save/share.
  void failConfirming(Failure failure) {
    state = state.copyWith(
      confirmingProposalId: null,
      actionFailure: failure,
    );
  }

  /// Clears Confirm busy state when the host is unmounted mid-export.
  void clearConfirming() {
    if (state.confirmingProposalId == null) {
      return;
    }
    state = state.copyWith(confirmingProposalId: null);
  }

  /// Commits money, a contact, a ledger, a statement confirm-state, or a plan.
  ///
  /// [sendOutreach] is ignored for money tools. Closing-plan default is
  /// **false** so a stray confirm cannot silent-send. Pass `true` only from
  /// Confirm & send. [autoDispatch] is test-only; production always
  /// auto-dispatches after the desk opens on the send path.
  Future<void> confirm(
    AgentProposal proposal, {
    bool sendOutreach = false,
    @visibleForTesting bool autoDispatch = true,
  }) async {
    if (state.confirmingProposalId != null &&
        state.confirmingProposalId != proposal.proposalId) {
      return;
    }
    if (state.confirmingProposalId == null) {
      state = state.copyWith(
        confirmingProposalId: proposal.proposalId,
        actionFailure: null,
      );
    }
    if (proposal.tool == ProposalTool.proposeCreateContact &&
        !_createIfMissing(proposal)) {
      final picked = state.contactIdByProposal[proposal.proposalId]?.trim();
      if (picked != null && picked.isNotEmpty) {
        state = state.copyWith(
          confirmingProposalId: null,
          committedIds: {...state.committedIds, proposal.proposalId},
        );
        return;
      }
    }
    final result = await ref
        .read(commitAgentProposalUseCaseProvider)
        .execute(
          proposal: proposal,
          ledgerIdOverride: state.ledgerIdByProposal[proposal.proposalId],
          currencyCodeOverride:
              state.currencyCodeByProposal[proposal.proposalId],
          contactIdOverride: state.contactIdByProposal[proposal.proposalId],
          nameOverride: state.nameByProposal[proposal.proposalId],
          phoneOverride: state.phoneByProposal[proposal.proposalId],
          ledgerNameOverride: state.ledgerNameByProposal[proposal.proposalId],
          amountMinorOverride: state.amountMinorByProposal[proposal.proposalId],
          createIfMissing: _createIfMissing(proposal),
        );
    final failure = result.getLeft().toNullable();
    if (failure != null) {
      state = state.copyWith(
        confirmingProposalId: null,
        actionFailure: failure,
      );
      return;
    }
    final value = result.getRight().toNullable()!;
    if (value.status == ConfirmProposalStatus.rejectedInFlight) {
      state = state.copyWith(
        confirmingProposalId: null,
        actionFailure: const ValidationFailure(
          'Confirm already in flight for this proposal.',
          code: 'proposal_in_flight',
        ),
      );
      return;
    }
    state = state.copyWith(
      confirmingProposalId: null,
      committedIds: {...state.committedIds, proposal.proposalId},
    );
    if (proposal.tool == ProposalTool.proposeClosingPlan) {
      _sendOutreach = sendOutreach;
      _autoDispatchOutreach = autoDispatch;
      await _runClosingRitual();
    }
  }

  /// Commits a compound capture bundle in ledger → contact → money order.
  ///
  /// Threads new ledger and contact ids into later steps. Stops on the first
  /// [Failure] without rolling back earlier committed writes.
  Future<void> confirmCaptureBundle(List<AgentProposal> bundle) async {
    if (!shouldBundleCaptureProposals(bundle)) {
      return;
    }
    final ordered = orderCaptureProposals(bundle);
    final bundleKey = captureBundleKey(ordered);
    final bundleIds = ordered.map((proposal) => proposal.proposalId).toSet();

    if (state.confirmingProposalId != null &&
        state.confirmingProposalId != bundleKey &&
        !bundleIds.contains(state.confirmingProposalId)) {
      return;
    }
    if (state.confirmingProposalId == null) {
      state = state.copyWith(
        confirmingProposalId: bundleKey,
        actionFailure: null,
      );
    }

    String? threadedLedgerId;
    String? threadedContactId;
    var contactCreatedInBundle = false;

    for (final proposal in ordered) {
      if (state.committedIds.contains(proposal.proposalId)) {
        if (proposal.tool == ProposalTool.proposeCreateLedger) {
          threadedLedgerId =
              state.ledgerIdByProposal[proposal.proposalId] ?? threadedLedgerId;
        } else if (proposal.tool == ProposalTool.proposeCreateContact) {
          threadedContactId =
              state.contactIdByProposal[proposal.proposalId] ??
              threadedContactId;
          contactCreatedInBundle = true;
        }
        continue;
      }

      if (proposal.tool == ProposalTool.proposeCreateContact &&
          !_createIfMissing(proposal)) {
        final picked = state.contactIdByProposal[proposal.proposalId]?.trim();
        if (picked != null && picked.isNotEmpty) {
          threadedContactId = picked;
          state = state.copyWith(
            committedIds: {...state.committedIds, proposal.proposalId},
            contactIdByProposal: _threadContactId(
              ordered: ordered,
              fromProposalId: proposal.proposalId,
              contactId: picked,
            ),
          );
          continue;
        }
      }

      final ledgerOverride = _bundleLedgerOverride(
        proposal: proposal,
        threadedLedgerId: threadedLedgerId,
        ordered: ordered,
      );
      final contactOverride = _bundleContactOverride(
        proposal: proposal,
        threadedContactId: threadedContactId,
      );
      final createIfMissing = _bundleCreateIfMissing(
        proposal: proposal,
        contactCreatedInBundle: contactCreatedInBundle,
      );

      final result = await ref
          .read(commitAgentProposalUseCaseProvider)
          .execute(
            proposal: proposal,
            ledgerIdOverride: ledgerOverride,
            currencyCodeOverride:
                state.currencyCodeByProposal[proposal.proposalId],
            contactIdOverride: contactOverride,
            nameOverride: state.nameByProposal[proposal.proposalId],
            phoneOverride: state.phoneByProposal[proposal.proposalId],
            ledgerNameOverride: state.ledgerNameByProposal[proposal.proposalId],
            amountMinorOverride: state.amountMinorByProposal[proposal.proposalId],
            createIfMissing: createIfMissing,
          );
      final failure = result.getLeft().toNullable();
      if (failure != null) {
        state = state.copyWith(
          confirmingProposalId: null,
          actionFailure: failure,
        );
        return;
      }
      final value = result.getRight().toNullable()!;
      if (value.status == ConfirmProposalStatus.rejectedInFlight) {
        state = state.copyWith(
          confirmingProposalId: null,
          actionFailure: const ValidationFailure(
            'Confirm already in flight for this proposal.',
            code: 'proposal_in_flight',
          ),
        );
        return;
      }

      var nextLedgerMap = state.ledgerIdByProposal;
      var nextContactMap = state.contactIdByProposal;

      if (proposal.tool == ProposalTool.proposeCreateLedger) {
        threadedLedgerId = value.entityId;
        nextLedgerMap = _threadLedgerId(
          ordered: ordered,
          fromProposalId: proposal.proposalId,
          ledgerId: threadedLedgerId!,
        );
      } else if (proposal.tool == ProposalTool.proposeCreateContact) {
        threadedContactId = value.entityId;
        contactCreatedInBundle = true;
        nextContactMap = _threadContactId(
          ordered: ordered,
          fromProposalId: proposal.proposalId,
          contactId: threadedContactId!,
        );
      }

      state = state.copyWith(
        committedIds: {...state.committedIds, proposal.proposalId},
        ledgerIdByProposal: nextLedgerMap,
        contactIdByProposal: nextContactMap,
      );
    }

    state = state.copyWith(confirmingProposalId: null);
  }

  /// Skips every pending proposal in a capture bundle.
  Future<void> cancelCaptureBundle(List<AgentProposal> bundle) async {
    if (!shouldBundleCaptureProposals(bundle)) {
      return;
    }
    for (final proposal in orderCaptureProposals(bundle)) {
      if (state.committedIds.contains(proposal.proposalId) ||
          state.skippedIds.contains(proposal.proposalId)) {
        continue;
      }
      await cancel(proposal.proposalId);
      if (state.actionFailure != null) {
        return;
      }
    }
  }

  Map<String, String> _threadLedgerId({
    required List<AgentProposal> ordered,
    required String fromProposalId,
    required String ledgerId,
  }) {
    return {
      ...state.ledgerIdByProposal,
      fromProposalId: ledgerId,
      for (final proposal in ordered)
        if (proposal.proposalId != fromProposalId &&
            (proposal.tool == ProposalTool.proposeCreateContact ||
                proposal.tool == ProposalTool.proposeDebt ||
                proposal.tool == ProposalTool.proposePayment ||
                proposal.tool == ProposalTool.proposeStatement))
          proposal.proposalId: ledgerId,
    };
  }

  Map<String, String> _threadContactId({
    required List<AgentProposal> ordered,
    required String fromProposalId,
    required String contactId,
  }) {
    return {
      ...state.contactIdByProposal,
      fromProposalId: contactId,
      for (final proposal in ordered)
        if (proposal.proposalId != fromProposalId &&
            (proposal.tool == ProposalTool.proposeDebt ||
                proposal.tool == ProposalTool.proposePayment ||
                proposal.tool == ProposalTool.proposeStatement))
          proposal.proposalId: contactId,
    };
  }

  String? _bundleLedgerOverride({
    required AgentProposal proposal,
    required String? threadedLedgerId,
    required List<AgentProposal> ordered,
  }) {
    final bundleCreatesLedger = ordered.any(
      (step) => step.tool == ProposalTool.proposeCreateLedger,
    );
    if (bundleCreatesLedger &&
        (proposal.tool == ProposalTool.proposeCreateContact ||
            proposal.tool == ProposalTool.proposeDebt ||
            proposal.tool == ProposalTool.proposePayment ||
            proposal.tool == ProposalTool.proposeStatement)) {
      return threadedLedgerId;
    }
    final picked = state.ledgerIdByProposal[proposal.proposalId]?.trim();
    if (picked != null && picked.isNotEmpty) {
      return picked;
    }
    return threadedLedgerId;
  }

  String? _bundleContactOverride({
    required AgentProposal proposal,
    required String? threadedContactId,
  }) {
    final picked = state.contactIdByProposal[proposal.proposalId]?.trim();
    if (picked != null && picked.isNotEmpty) {
      return picked;
    }
    return threadedContactId;
  }

  bool _bundleCreateIfMissing({
    required AgentProposal proposal,
    required bool contactCreatedInBundle,
  }) {
    if (contactCreatedInBundle &&
        (proposal.tool == ProposalTool.proposeDebt ||
            proposal.tool == ProposalTool.proposePayment)) {
      return false;
    }
    return _createIfMissing(proposal);
  }

  /// Retries the close-the-day ritual after a failed snapshot/backup/shortlist.
  Future<void> retryClosingRitual() => _runClosingRitual();

  /// Stores Yes / Top 5 / No. [ClosingReminderPolicy.none] skips PDFs.
  void chooseReminderPolicy(ClosingReminderPolicy policy) {
    final current = state.ritualResult;
    if (current == null ||
        state.phase != ClosingAgentPhase.ritualPrompt ||
        state.ritualPromptKind != ClosingRitualPromptKind.reminders) {
      return;
    }
    final next = current.withReminderPolicy(policy);
    if (policy == ClosingReminderPolicy.none) {
      _showRitualReport(next);
      return;
    }
    state = state.copyWith(
      ritualResult: next,
      ritualPromptKind: ClosingRitualPromptKind.pdfs,
    );
  }

  /// Restores an in-flight Hybrid E queue after process death.
  Future<void> hydrateInFlightQueue() async {
    if (state.queueStatus != null) {
      return;
    }
    if (state.phase != ClosingAgentPhase.idle &&
        state.phase != ClosingAgentPhase.ready) {
      return;
    }
    final loaded = await ref
        .read(loadInFlightCollectionsSendQueueUseCaseProvider)
        .execute();
    final failure = loaded.getLeft().toNullable();
    if (failure != null) {
      return;
    }
    final queue = loaded.getRight().toNullable();
    if (queue == null || queue.batchId != null) {
      return;
    }
    state = state.copyWith(
      phase: ClosingAgentPhase.ritualDesk,
      ritualResult: queue.ritual,
      ritualPromptKind: null,
      deskRows: queue.rows,
      deskLocale: queue.locale,
      deskStoreName: queue.storeName,
      queueId: queue.id,
      queueStatus: queue.status,
      queueAwaitingResume: false,
      queueCreatedAt: queue.createdAt,
      deskBusyContactId: null,
      actionFailure: null,
    );
    if (queue.awaitingResume &&
        queue.status == CollectionsSendQueueStatus.active) {
      await _persistQueue();
      await HapticService.selection();
    }
  }

  /// Advances the sticky offer after returning from WhatsApp / share sheet.
  ///
  /// Does not launch `wa.me` (no silent send, no extra chat without a tap).
  /// Re-checks contacts and microphone so Open Settings can clear banners.
  Future<void> onHostResumed({
    Future<bool> Function()? hasContactsReadPermission,
    Future<bool> Function()? hasMicrophonePermission,
  }) async {
    await refreshContactsPermissionBanner(
      hasReadPermission: hasContactsReadPermission,
    );
    await refreshMicPermissionBanner(
      hasMicrophonePermission: hasMicrophonePermission,
    );
    if (state.phase != ClosingAgentPhase.ritualDesk ||
        state.queueStatus != CollectionsSendQueueStatus.active ||
        !state.queueAwaitingResume) {
      return;
    }
    state = state.copyWith(queueAwaitingResume: false);
    await _persistQueue();
    await HapticService.selection();
  }

  /// Clears the mic-denied banner when the OS grant is restored.
  ///
  /// [hasMicrophonePermission] is injected by the host (never loops
  /// `Permission.request` after a permanent deny). No-op without a checker.
  Future<void> refreshMicPermissionBanner({
    Future<bool> Function()? hasMicrophonePermission,
  }) async {
    if (state.micBannerKind != ClosingMicBannerKind.permissionDenied) {
      return;
    }
    if (hasMicrophonePermission == null) {
      return;
    }
    if (await hasMicrophonePermission()) {
      state = state.copyWith(micBannerKind: null);
    }
  }

  /// Clears the contacts banner when the OS grant is restored.
  Future<void> refreshContactsPermissionBanner({
    Future<bool> Function()? hasReadPermission,
  }) async {
    if (!state.contactsPermissionDenied) {
      return;
    }
    final checker =
        hasReadPermission ?? NativeContactPickerService.hasReadPermission;
    if (await checker()) {
      state = state.copyWith(contactsPermissionDenied: false);
    }
  }

  /// Stops auto-advance on resume. Open / Skip remain available.
  Future<void> pauseSendQueue() async {
    if (state.queueStatus != CollectionsSendQueueStatus.active) {
      return;
    }
    state = state.copyWith(
      queueStatus: CollectionsSendQueueStatus.paused,
      queueAwaitingResume: false,
    );
    await _persistQueue();
  }

  /// Resumes auto-advance on the next host resume. Does not open WhatsApp.
  Future<void> resumeSendQueue() async {
    if (state.queueStatus != CollectionsSendQueueStatus.paused) {
      return;
    }
    state = state.copyWith(queueStatus: CollectionsSendQueueStatus.active);
    await _persistQueue();
  }

  /// Stores PDF policy after Yes / Top 5, then opens the Desk when needed.
  Future<void> choosePdfPolicy(ClosingPdfPolicy policy) async {
    final current = state.ritualResult;
    if (_buildingDesk ||
        current == null ||
        state.phase != ClosingAgentPhase.ritualPrompt ||
        state.ritualPromptKind != ClosingRitualPromptKind.pdfs) {
      return;
    }
    final next = current.withPdfPolicy(policy);
    await _openCollectionsDesk(next);
  }

  /// Marks a pending desk row skipped. Completes the Desk when none remain.
  Future<void> skipDeskRow(String contactId) async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final current = _deskRow(contactId);
    if (current == null || current.status != CollectionsDeskRowStatus.pending) {
      return;
    }
    await _commitDeskRows(
      _replaceDeskRow(
        current.copyWith(status: CollectionsDeskRowStatus.skipped),
      ),
    );
  }

  /// Regenerates the draft body after a tone override. Does not retune aging.
  Future<void> setDeskTone(String contactId, ReminderToneBand tone) async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final current = _deskRow(contactId);
    if (current == null ||
        current.status != CollectionsDeskRowStatus.pending ||
        current.toneBand == tone) {
      return;
    }
    final body = ref
        .read(composeCollectionsReminderDraftUseCaseProvider)
        .execute(
          candidate: current.candidate,
          tone: tone,
          locale: state.deskLocale,
          storeName: state.deskStoreName,
        );
    await _commitDeskRows(
      _replaceDeskRow(
        current.copyWith(
          toneBand: tone,
          subject: body.subject,
          body: body.body,
          customerName: body.customerName,
          storeName: body.storeName,
          amountLine: body.amountLine,
          ctaLine: body.ctaLine,
          note: body.note,
        ),
      ),
    );
  }

  /// Adds or removes statement-PDF attach for a pending row.
  Future<void> toggleDeskPdf(String contactId) async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final current = _deskRow(contactId);
    if (current == null || current.status != CollectionsDeskRowStatus.pending) {
      return;
    }
    await _commitDeskRows(
      _replaceDeskRow(
        current.copyWith(attachPdf: !current.attachPdf),
      ),
    );
  }

  /// Copies the draft body to the clipboard.
  Future<void> copyDeskRow(String contactId) async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final current = _deskRow(contactId);
    if (current == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: current.body));
    await HapticService.success();
  }

  /// Leftover Hybrid E Open (`wa.me` or share-sheet). Not the filmed climax
  /// and not the missing-email fallback — Approve uses SMTP MIME.
  ///
  /// [sharePdf] must present the OS share sheet and return whether it did.
  Future<void> openDeskRow({
    required String contactId,
    required Future<bool> Function(CollectionsDeskRow row) sharePdf,
  }) async {
    if (state.phase != ClosingAgentPhase.ritualDesk ||
        state.deskBusyContactId != null) {
      return;
    }
    final current = _deskRow(contactId);
    if (current == null || current.status != CollectionsDeskRowStatus.pending) {
      return;
    }
    state = state.copyWith(
      deskBusyContactId: contactId,
      actionFailure: null,
    );
    if (current.attachPdf) {
      final didShare = await sharePdf(current);
      if (state.phase != ClosingAgentPhase.ritualDesk) {
        return;
      }
      if (!didShare) {
        state = state.copyWith(deskBusyContactId: null);
        return;
      }
      await _markDeskOpened(contactId);
      return;
    }
    final opened = await ref
        .read(collectionsWhatsAppOpenerProvider)
        .open(
          phone: current.candidate.phone ?? '',
          message: current.body,
        );
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    if (!opened) {
      state = state.copyWith(
        deskBusyContactId: null,
        actionFailure: _whatsAppOpenFailed,
      );
      return;
    }
    await _markDeskOpened(contactId);
  }

  /// Leftover Hybrid E Start sending. Not the filmed climax and not the
  /// missing-email fallback. Approve uses [approveAndSend].
  Future<void> startSending({
    required Future<bool> Function(CollectionsDeskRow row) sharePdf,
  }) async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final firstPending = state.firstPendingDeskRow;
    if (firstPending == null) {
      await finishDesk();
      return;
    }
    await _ensureQueueStarted();
    await openDeskRow(
      contactId: firstPending.candidate.contactId,
      sharePdf: sharePdf,
    );
  }

  /// Skip outreach: remaining pending → skipped. No SMTP.
  Future<void> skipOutreach() async {
    if (state.ritualDeskPreflightPending &&
        state.phase == ClosingAgentPhase.ritualRunning) {
      final ritual = state.ritualResult;
      if (ritual == null) {
        return;
      }
      state = state.copyWith(ritualDeskPreflightPending: false);
      await _skipRitualTask(ClosingTaskId.openCollectionsDesk);
      _showRitualReport(ritual);
      return;
    }
    await finishDesk();
  }

  /// Approve & send the send set via Cloud Run send-batch. Never opens `wa.me`.
  Future<void> approveAndSend() async {
    if (state.phase != ClosingAgentPhase.ritualDesk ||
        state.collectionsDispatching) {
      return;
    }
    final pending = [
      for (final row in state.deskRows)
        if (row.status == CollectionsDeskRowStatus.pending) row,
    ];
    if (pending.isEmpty) {
      await finishDesk();
      return;
    }

    final tokenResult = await ref
        .read(hydrateAgentIdTokenUseCaseProvider)
        .execute();
    final tokenFailure = tokenResult.getLeft().toNullable();
    if (tokenFailure != null) {
      state = state.copyWith(actionFailure: tokenFailure);
      return;
    }

    final batchId = UuidUtil.generate();
    final correlationId =
        state.turnResult?.correlationId.trim().isNotEmpty == true
        ? state.turnResult!.correlationId
        : UuidUtil.generate();

    state = state.copyWith(
      collectionsDispatching: true,
      collectionsBatchId: batchId,
      actionFailure: null,
      deskBusyContactId: null,
    );

    final dispatched = await ref
        .read(dispatchCollectionsEmailUseCaseProvider)
        .execute(
          rows: pending,
          locale: state.deskLocale,
          storeName: state.deskStoreName,
          batchId: batchId,
          correlationId: correlationId,
          isRtl: state.deskLocale != 'en',
          onRows: (rows) {
            state = state.copyWith(
              deskRows: _mergeDeskRows(rows),
            );
          },
        );

    final ok = dispatched.getRight().toNullable();
    final failure = dispatched.getLeft().toNullable();
    final latestRows = _mergeDeskRows(ok?.rows ?? state.deskRows);
    final metrics = ok?.metrics ?? CollectionsQueueMetrics.fromRows(latestRows);
    final ritual = state.ritualResult;
    state = state.copyWith(
      collectionsDispatching: false,
      deskRows: latestRows,
    );

    if (failure != null &&
        failure.code != 'smtp_needs_human' &&
        failure.code != 'smtp_sender_misconfigured') {
      state = state.copyWith(actionFailure: failure);
      await _persistSmtpQueue(batchId: batchId, rows: latestRows);
      return;
    }

    if (ritual != null) {
      _showRitualReport(
        ritual.withQueueMetrics(metrics),
      );
    }
    if (failure != null) {
      state = state.copyWith(actionFailure: failure);
    }
    await _persistSmtpQueue(batchId: batchId, rows: latestRows);
    await _completePersistedQueue();
  }

  List<CollectionsDeskRow> _mergeDeskRows(List<CollectionsDeskRow> incoming) {
    final byId = {
      for (final row in incoming) row.candidate.contactId: row,
    };
    return [
      for (final row in state.deskRows) byId[row.candidate.contactId] ?? row,
    ];
  }

  Future<void> _persistSmtpQueue({
    required String batchId,
    required List<CollectionsDeskRow> rows,
  }) async {
    final ritual = state.ritualResult;
    if (ritual == null) {
      return;
    }
    final id = state.queueId ?? UuidUtil.generate();
    final created = state.queueCreatedAt ?? DateTime.now().toUtc();
    state = state.copyWith(
      queueId: id,
      queueCreatedAt: created,
      collectionsBatchId: batchId,
      queueStatus: CollectionsSendQueueStatus.completed,
      queueAwaitingResume: false,
    );
    final saved = await ref
        .read(saveCollectionsSendQueueUseCaseProvider)
        .execute(
          CollectionsSendQueue(
            id: id,
            status: CollectionsSendQueueStatus.completed,
            awaitingResume: false,
            locale: state.deskLocale,
            storeName: state.deskStoreName,
            ritual: ritual,
            rows: rows,
            createdAt: created,
            updatedAt: DateTime.now().toUtc(),
            batchId: batchId,
          ),
        );
    final persistFailure = saved.getLeft().toNullable();
    if (persistFailure != null) {
      state = state.copyWith(actionFailure: persistFailure);
    }
  }

  /// Shows the hero report. Remaining pending rows are treated as skipped.
  Future<void> finishDesk() async {
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    final result = state.ritualResult;
    if (result == null) {
      return;
    }
    final rows = [
      for (final row in state.deskRows)
        if (row.status == CollectionsDeskRowStatus.pending)
          row.copyWith(status: CollectionsDeskRowStatus.skipped)
        else
          row,
    ];
    state = state.copyWith(deskRows: rows);
    final metrics = CollectionsQueueMetrics.fromRows(rows);
    _showRitualReport(result.withQueueMetrics(metrics));
    await _completePersistedQueue();
  }

  /// Surfaces a share/PDF failure from the Collections Desk UI.
  void notifyActionFailure(Failure failure) {
    state = state.copyWith(
      actionFailure: failure,
      deskBusyContactId: null,
    );
  }

  Future<void> _runClosingRitual() async {
    _resetRitualTasks();
    state = state.copyWith(
      phase: ClosingAgentPhase.ritualRunning,
      actionFailure: null,
      ritualRetryAvailable: false,
      ritualPromptKind: null,
      ritualResult: null,
    );

    final day = ClosingAgentConstants.merchantLocalDay();

    await _pulseRitualTask(ClosingTaskId.bindLedger);

    final summaryResult = await ref
        .read(getClosingDaySummaryUseCaseProvider)
        .execute(localDay: day);
    final summaryFailure = summaryResult.getLeft().toNullable();
    if (summaryFailure != null) {
      state = state.copyWith(
        phase: ClosingAgentPhase.ready,
        actionFailure: summaryFailure,
        ritualRetryAvailable: true,
        ritualTaskCurrent: null,
      );
      return;
    }
    final summary = summaryResult.getRight().toNullable()!;
    state = state.copyWith(ritualTaskSummary: summary);
    await _staggerCompleteTasks(const [
      ClosingTaskId.collectDebts,
      ClosingTaskId.collectPayments,
      ClosingTaskId.tallyTotals,
      ClosingTaskId.stampSnapshot,
    ]);

    await _pulseRitualTask(ClosingTaskId.prepareVaultPayload);

    final backupResult = await ref
        .read(uploadDriveBackupUseCaseProvider)
        .call();
    final backupStatus = mapClosingBackupStatus(backupResult);
    final backupFailed = backupStatus == ClosingBackupStatus.failed;
    await _pulseRitualTask(ClosingTaskId.sealDriveBackup);
    state = state.copyWith(
      ritualBackupFailed: backupFailed,
      ritualBackupStatus: backupStatus,
    );

    final shortlistResult = await ref
        .read(getCollectionsCandidatesUseCaseProvider)
        .execute();
    final shortlistFailure = shortlistResult.getLeft().toNullable();
    if (shortlistFailure != null) {
      state = state.copyWith(
        phase: ClosingAgentPhase.ready,
        actionFailure: shortlistFailure,
        ritualRetryAvailable: true,
        ritualTaskCurrent: null,
      );
      return;
    }
    final shortlist = shortlistResult.getRight().toNullable() ?? const [];
    state = state.copyWith(ritualOverdueCount: shortlist.length);
    await _staggerCompleteTasks(const [
      ClosingTaskId.scanAging,
      ClosingTaskId.rankUrgency,
      ClosingTaskId.buildSendSet,
    ]);

    final ritual = ClosingRitualResult(
      summary: summary,
      backupStatus: backupStatus,
      shortlist: shortlist,
      needsHuman: backupStatus != ClosingBackupStatus.uploaded,
    );

    if (shortlist.isEmpty) {
      await _skipRitualTask(ClosingTaskId.openCollectionsDesk);
      await _completeReportTasks();
      _showRitualReport(ritual);
      return;
    }

    final planned = ritual
        .withReminderPolicy(ClosingReminderPolicy.all)
        .withPdfPolicy(ClosingPdfPolicy.rankedTop5);

    if (!_sendOutreach) {
      await _finishCloseWithoutOutreach(planned);
      return;
    }

    state = state.copyWith(
      ritualResult: planned,
      ritualTaskCurrent: ClosingTaskId.openCollectionsDesk,
    );

    final sendPreflight = await _preflightCollectionsSend();
    if (sendPreflight != null) {
      state = state.copyWith(
        ritualDeskPreflightPending: true,
        actionFailure: sendPreflight,
      );
      return;
    }

    await _openCollectionsDesk(planned);
    await _maybeAutoDispatchOutreach();
  }

  Future<void> _finishCloseWithoutOutreach(ClosingRitualResult ritual) async {
    final prepared = ritual.reminderSet.length;
    await _skipRitualTask(ClosingTaskId.openCollectionsDesk);
    await _completeReportTasks();
    _showRitualReport(
      ritual.withQueueMetrics(
        CollectionsQueueMetrics(
          prepared: prepared,
          opened: 0,
          skipped: prepared,
        ),
      ),
    );
  }

  Future<void> _maybeAutoDispatchOutreach() async {
    if (!_autoDispatchOutreach || !_sendOutreach) {
      return;
    }
    if (state.phase != ClosingAgentPhase.ritualDesk) {
      return;
    }
    await approveAndSend();
  }

  void _resetRitualTasks() {
    state = state.copyWith(
      ritualTasksDone: const {},
      ritualTasksSkipped: const {},
      ritualTaskCurrent: ClosingTaskId.bindLedger,
      ritualTaskSummary: null,
      ritualOverdueCount: 0,
      ritualBackupFailed: false,
      ritualBackupStatus: null,
      ritualDeskPreflightPending: false,
    );
  }

  /// Verifies Google ID-token / openid grant before Collections Desk opens.
  Future<Failure?> _preflightCollectionsSend() async {
    if (!ref.mounted) {
      return null;
    }
    final tokenResult = await ref
        .read(hydrateAgentIdTokenUseCaseProvider)
        .execute();
    return tokenResult.getLeft().toNullable();
  }

  /// Opens the desk after send preflight succeeds (e.g. post Google grant).
  Future<void> resumeCollectionsDeskAfterPreflight() async {
    if (!state.ritualDeskPreflightPending ||
        state.phase != ClosingAgentPhase.ritualRunning) {
      return;
    }
    final ritual = state.ritualResult;
    if (ritual == null) {
      state = state.copyWith(ritualDeskPreflightPending: false);
      return;
    }
    final sendPreflight = await _preflightCollectionsSend();
    if (sendPreflight != null) {
      state = state.copyWith(actionFailure: sendPreflight);
      return;
    }
    state = state.copyWith(
      ritualDeskPreflightPending: false,
      actionFailure: null,
    );
    await _openCollectionsDesk(
      ritual
          .withReminderPolicy(ClosingReminderPolicy.all)
          .withPdfPolicy(ClosingPdfPolicy.rankedTop5),
    );
    await _maybeAutoDispatchOutreach();
  }

  Future<void> _pulseRitualTask(ClosingTaskId id) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(ritualTaskCurrent: id);
    await Future<void>.delayed(ClosingAgentController.ritualPulseDelay);
    if (!ref.mounted) {
      return;
    }
    await _completeRitualTask(id);
  }

  Future<void> _completeRitualTask(ClosingTaskId id) async {
    if (!ref.mounted) {
      return;
    }
    if (state.ritualTasksDone.contains(id)) {
      return;
    }
    final done = {...state.ritualTasksDone, id};
    state = state.copyWith(
      ritualTasksDone: done,
      ritualTaskCurrent: ClosingTaskOrder.next(id),
    );
    unawaited(HapticService.selection());
  }

  Future<void> _skipRitualTask(ClosingTaskId id) async {
    state = state.copyWith(
      ritualTasksSkipped: {...state.ritualTasksSkipped, id},
      ritualTaskCurrent: ClosingTaskOrder.next(id),
    );
  }

  Future<void> _staggerCompleteTasks(List<ClosingTaskId> ids) async {
    for (final id in ids) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(ritualTaskCurrent: id);
      await Future<void>.delayed(ClosingAgentController.ritualStaggerDelay);
      if (!ref.mounted) {
        return;
      }
      await _completeRitualTask(id);
    }
  }

  Future<void> _completeReportTasks() async {
    if (!ref.mounted) {
      return;
    }
    if (!state.ritualTasksSkipped.contains(ClosingTaskId.openCollectionsDesk) &&
        !state.ritualTasksDone.contains(ClosingTaskId.openCollectionsDesk)) {
      await _completeRitualTask(ClosingTaskId.openCollectionsDesk);
    }
    if (!ref.mounted) {
      return;
    }
    await _staggerCompleteTasks(const [
      ClosingTaskId.composeReport,
      ClosingTaskId.presentSeal,
    ]);
  }

  void _syncCompleteReportTasks() {
    if (!ref.mounted) {
      return;
    }
    var done = state.ritualTasksDone;
    if (!state.ritualTasksSkipped.contains(ClosingTaskId.openCollectionsDesk) &&
        !done.contains(ClosingTaskId.openCollectionsDesk)) {
      done = {...done, ClosingTaskId.openCollectionsDesk};
    }
    done = {
      ...done,
      ClosingTaskId.composeReport,
      ClosingTaskId.presentSeal,
    };
    state = state.copyWith(
      ritualTasksDone: done,
      ritualTaskCurrent: null,
    );
  }

  Future<void> _openCollectionsDesk(ClosingRitualResult next) async {
    if (_buildingDesk) {
      return;
    }
    if (next.reminderSet.isEmpty) {
      _showRitualReport(next);
      return;
    }
    _buildingDesk = true;
    try {
      final built = await ref
          .read(buildCollectionsDeskUseCaseProvider)
          .execute(next);
      final failure = built.getLeft().toNullable();
      if (failure != null) {
        state = state.copyWith(
          ritualResult: next,
          actionFailure: failure,
        );
        return;
      }
      final snapshot = built.getRight().toNullable()!;
      if (snapshot.rows.isEmpty) {
        _showRitualReport(next);
        return;
      }
      state = state.copyWith(
        phase: ClosingAgentPhase.ritualDesk,
        ritualResult: next,
        ritualPromptKind: null,
        deskRows: snapshot.rows,
        deskLocale: snapshot.locale,
        deskStoreName: snapshot.storeName,
        deskBusyContactId: null,
        collectionsDispatching: false,
        collectionsBatchId: null,
        actionFailure: null,
      );
    } finally {
      _buildingDesk = false;
    }
  }

  void _showRitualReport(ClosingRitualResult result) {
    _syncCompleteReportTasks();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      phase: ClosingAgentPhase.ritualReport,
      ritualResult: result,
      ritualPromptKind: null,
      ritualRetryAvailable: false,
      ritualTaskCurrent: null,
      deskBusyContactId: null,
    );
  }

  CollectionsDeskRow? _deskRow(String contactId) {
    for (final row in state.deskRows) {
      if (row.candidate.contactId == contactId) {
        return row;
      }
    }
    return null;
  }

  List<CollectionsDeskRow> _replaceDeskRow(CollectionsDeskRow next) {
    return [
      for (final row in state.deskRows)
        if (row.candidate.contactId == next.candidate.contactId) next else row,
    ];
  }

  Future<void> _markDeskOpened(String contactId) async {
    final current = _deskRow(contactId);
    if (current == null) {
      state = state.copyWith(deskBusyContactId: null);
      return;
    }
    await _commitDeskRows(
      _replaceDeskRow(
        current.copyWith(status: CollectionsDeskRowStatus.opened),
      ),
      markAwaitingResume:
          state.queueStatus == CollectionsSendQueueStatus.active,
    );
  }

  Future<void> _commitDeskRows(
    List<CollectionsDeskRow> rows, {
    bool markAwaitingResume = false,
  }) async {
    final complete =
        rows.isNotEmpty &&
        rows.every(
          (row) =>
              row.status == CollectionsDeskRowStatus.skipped ||
              row.status == CollectionsDeskRowStatus.opened ||
              row.status == CollectionsDeskRowStatus.sent ||
              row.status == CollectionsDeskRowStatus.failed,
        );
    if (complete) {
      final result = state.ritualResult;
      final metrics = CollectionsQueueMetrics.fromRows(rows);
      state = state.copyWith(
        deskRows: rows,
        deskBusyContactId: null,
      );
      if (result != null) {
        _showRitualReport(result.withQueueMetrics(metrics));
      }
      await _completePersistedQueue();
      return;
    }
    state = state.copyWith(
      deskRows: rows,
      deskBusyContactId: null,
      queueAwaitingResume: markAwaitingResume || state.queueAwaitingResume,
    );
    if (state.queueId != null) {
      await _persistQueue();
    }
  }

  Future<void> _ensureQueueStarted() async {
    if (state.queueId != null || state.ritualResult == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    state = state.copyWith(
      queueId: UuidUtil.generate(),
      queueStatus: CollectionsSendQueueStatus.active,
      queueAwaitingResume: false,
      queueCreatedAt: now,
    );
    await _persistQueue();
  }

  Future<void> _persistQueue() async {
    final id = state.queueId;
    final status = state.queueStatus;
    final ritual = state.ritualResult;
    final created = state.queueCreatedAt;
    if (id == null || status == null || ritual == null || created == null) {
      return;
    }
    final saved = await ref
        .read(saveCollectionsSendQueueUseCaseProvider)
        .execute(
          CollectionsSendQueue(
            id: id,
            status: status,
            awaitingResume: state.queueAwaitingResume,
            locale: state.deskLocale,
            storeName: state.deskStoreName,
            ritual: ritual,
            rows: state.deskRows,
            createdAt: created,
            updatedAt: DateTime.now().toUtc(),
            batchId: state.collectionsBatchId,
          ),
        );
    final failure = saved.getLeft().toNullable();
    if (failure != null) {
      state = state.copyWith(actionFailure: failure);
    }
  }

  Future<void> _completePersistedQueue() async {
    final id = state.queueId;
    if (id != null) {
      await ref.read(completeCollectionsSendQueueUseCaseProvider).execute(id);
    }
    if (state.queueId == id) {
      state = state.copyWith(
        queueId: null,
        queueStatus: null,
        queueAwaitingResume: false,
        queueCreatedAt: null,
        collectionsBatchId: null,
        collectionsDispatching: false,
      );
    }
  }

  /// Marks a proposal skipped. Never writes money and never journals.
  Future<void> cancel(String proposalId) async {
    final result = await ref
        .read(cancelAgentProposalUseCaseProvider)
        .execute(proposalId: proposalId);
    final failure = result.getLeft().toNullable();
    if (failure != null) {
      state = state.copyWith(actionFailure: failure);
      return;
    }
    state = state.copyWith(
      skippedIds: {...state.skippedIds, proposalId},
    );
  }

  /// Stores the ledger chosen for a `propose_create_contact` card.
  void setLedgerForProposal(String proposalId, String ledgerId) {
    state = state.copyWith(
      ledgerIdByProposal: {
        ...state.ledgerIdByProposal,
        proposalId: ledgerId,
      },
    );
  }

  /// Stores the currency chosen for a `propose_create_contact` card.
  void setCurrencyForProposal(String proposalId, String currencyCode) {
    state = state.copyWith(
      currencyCodeByProposal: {
        ...state.currencyCodeByProposal,
        proposalId: currencyCode,
      },
    );
  }

  /// Stores a new ledger name when the merchant has zero ledgers.
  void setLedgerNameForProposal(String proposalId, String ledgerName) {
    state = state.copyWith(
      ledgerNameByProposal: {
        ...state.ledgerNameByProposal,
        proposalId: ledgerName,
      },
    );
  }

  /// Stores the disambiguation contact chosen for a money or create proposal.
  void setContactForProposal(String proposalId, String contactId) {
    final createNew = Set<String>.from(state.createNewByProposal)
      ..remove(proposalId);
    state = state.copyWith(
      contactIdByProposal: {
        ...state.contactIdByProposal,
        proposalId: contactId,
      },
      createNewByProposal: createNew,
    );
  }

  /// Merchant chose Create new instead of a similar existing contact.
  void chooseCreateNewContact(String proposalId) {
    final ids = Map<String, String>.from(state.contactIdByProposal)
      ..remove(proposalId);
    state = state.copyWith(
      contactIdByProposal: ids,
      createNewByProposal: {...state.createNewByProposal, proposalId},
    );
  }

  /// Opens the native phone-contact picker and stores name/phone overrides.
  ///
  /// [picker] is for tests. Production uses [NativeContactPickerService].
  Future<void> pickPhoneContact(
    String proposalId, {
    Future<NativeContactPickOutcome> Function()? picker,
  }) async {
    if (!NativeContactPickerService.isSupported && picker == null) {
      return;
    }
    final outcome =
        await (picker ?? NativeContactPickerService.pickNameAndPhone)();
    applyContactPickOutcome(proposalId, outcome);
  }

  /// Applies a picker outcome. Deny shows the contacts banner; cancel is silent.
  void applyContactPickOutcome(
    String proposalId,
    NativeContactPickOutcome outcome,
  ) {
    switch (outcome) {
      case NativeContactPicked(:final result):
        final names = Map<String, String>.from(state.nameByProposal);
        names[proposalId] = result.name;
        final phones = Map<String, String>.from(state.phoneByProposal);
        final phone = result.phone?.trim();
        if (phone != null && phone.isNotEmpty) {
          phones[proposalId] = phone;
        }
        state = state.copyWith(
          nameByProposal: names,
          phoneByProposal: phones,
          contactsPermissionDenied: false,
        );
      case NativeContactCancelled():
        return;
      case NativeContactDenied():
        state = state.copyWith(contactsPermissionDenied: true);
    }
  }

  /// Resolves an ask-the-books ambiguous name to a Drift balance or last txn.
  ///
  /// The ask card speaks the new answer after it rebuilds.
  Future<void> resolveAskCandidate(String contactId) async {
    final result = await ref
        .read(answerAskBooksUseCaseProvider)
        .balanceForContact(
          contactId,
          intent: state.lastAskIntent ?? AskBooksIntent.namedBalance,
        );
    result.fold(
      (failure) => state = state.copyWith(actionFailure: failure),
      (answer) => state = state.copyWith(
        askAnswer: answer,
        lastAskContactId: contactId,
      ),
    );
  }

  /// Auto-fills `ledgerId` when exactly one active ledger exists.
  void applySoleLedgerIfNeeded(List<Ledger> ledgers) {
    if (ledgers.length != 1) {
      return;
    }
    final turn = state.turnResult;
    if (turn == null) {
      return;
    }
    final soleId = ledgers.single.id;
    final updated = Map<String, String>.from(state.ledgerIdByProposal);
    var changed = false;
    for (final proposal in turn.proposals) {
      if (proposal.tool != ProposalTool.proposeCreateContact) {
        continue;
      }
      final payload = proposal.payload;
      if (payload is! ProposeCreateContactPayload) {
        continue;
      }
      final fromPayload = payload.ledgerId?.trim();
      if (fromPayload != null && fromPayload.isNotEmpty) {
        continue;
      }
      if (updated.containsKey(proposal.proposalId)) {
        continue;
      }
      updated[proposal.proposalId] = soleId;
      changed = true;
    }
    if (changed) {
      state = state.copyWith(ledgerIdByProposal: updated);
    }
  }

  /// Shows a composer mic info banner (the one allowed lapis fill).
  void showMicBanner(ClosingMicBannerKind kind) {
    _holdHintDismissTimer?.cancel();
    _holdHintDismissTimer = null;
    state = state.copyWith(micBannerKind: kind);
    if (kind == ClosingMicBannerKind.holdHint) {
      _holdHintDismissTimer = Timer(holdHintVisible, () {
        if (state.micBannerKind == ClosingMicBannerKind.holdHint) {
          state = state.copyWith(micBannerKind: null);
        }
        _holdHintDismissTimer = null;
      });
    }
  }

  /// Hides the composer mic banner.
  void dismissMicBanner() {
    _clearMicBanner();
  }

  void _clearMicBanner() {
    _holdHintDismissTimer?.cancel();
    _holdHintDismissTimer = null;
    if (state.micBannerKind == null) {
      return;
    }
    state = state.copyWith(micBannerKind: null);
  }

  /// Clears a folded failure after the error sheet has been shown.
  void clearActionFailure() {
    if (state.actionFailure == null) {
      return;
    }
    state = state.copyWith(actionFailure: null);
  }

  void _failCloudCall(AskBooksAnswer? askAnswer, Failure failure) {
    state = state.copyWith(
      phase: askAnswer != null
          ? ClosingAgentPhase.ready
          : (state.turnResult == null
                ? ClosingAgentPhase.idle
                : ClosingAgentPhase.ready),
      actionFailure: failure,
    );
  }

  Future<
    ({
      Map<String, List<ContactSearchHit>> candidates,
      Map<String, String> ids,
      Failure? failure,
    })
  >
  _loadCandidates(AgentTurnResult turn, String lastGoalText) async {
    final candidates = <String, List<ContactSearchHit>>{};
    final ids = <String, String>{};
    Failure? failure;
    for (final proposal in turn.proposals) {
      final payload = proposal.payload;
      if (payload is ProposeStatementPayload) {
        final loaded = await _loadStatementCandidates(
          payload: payload,
          lastGoalText: lastGoalText,
        );
        failure ??= loaded.failure;
        if (loaded.hits != null) {
          candidates[proposal.proposalId] = loaded.hits!;
        }
        if (loaded.id != null) {
          ids[proposal.proposalId] = loaded.id!;
        }
        continue;
      }
      final hint = _candidateHint(proposal);
      if (hint == null) {
        continue;
      }
      final result = await ref
          .read(listAgentContactCandidatesUseCaseProvider)
          .execute(contactHint: hint);
      final left = result.getLeft().toNullable();
      if (left != null) {
        failure ??= left;
        continue;
      }
      final hits = result.getRight().toNullable() ?? const <ContactSearchHit>[];
      candidates[proposal.proposalId] = hits;
      final exactId = _exactUniqueContactId(hint, hits);
      if (exactId != null) {
        ids[proposal.proposalId] = exactId;
      }
    }
    return (candidates: candidates, ids: ids, failure: failure);
  }

  Future<({List<ContactSearchHit> hits, Failure? failure})>
  _searchStatementHint(String hint) async {
    final result = await ref
        .read(listAgentContactCandidatesUseCaseProvider)
        .execute(contactHint: hint);
    final left = result.getLeft().toNullable();
    if (left != null) {
      return (hits: const <ContactSearchHit>[], failure: left);
    }
    return (
      hits: result.getRight().toNullable() ?? const <ContactSearchHit>[],
      failure: null,
    );
  }

  Future<({List<ContactSearchHit>? hits, String? id, Failure? failure})>
  _loadStatementCandidates({
    required ProposeStatementPayload payload,
    required String lastGoalText,
  }) async {
    final payloadId = payload.contactId.trim();
    final fromPayload = nonUuidHint(payload.contactHint);
    final fromGoal = nonUuidHint(extractStatementContactHint(lastGoalText));
    final hint = fromPayload ?? fromGoal;

    var hits = const <ContactSearchHit>[];
    if (hint != null && hint.isNotEmpty) {
      final loaded = await _searchStatementHint(hint);
      if (loaded.failure != null) {
        return (hits: null, id: null, failure: loaded.failure);
      }
      hits = loaded.hits;
    }
    if (hits.isEmpty &&
        fromGoal != null &&
        fromGoal.isNotEmpty &&
        fromGoal != hint) {
      final loaded = await _searchStatementHint(fromGoal);
      if (loaded.failure != null) {
        return (hits: null, id: null, failure: loaded.failure);
      }
      hits = loaded.hits;
    }

    if (hits.length > 1) {
      final preselect =
          payloadId.isNotEmpty &&
          hits.any((hit) => hit.contact.id == payloadId);
      return (
        hits: hits,
        id: preselect ? payloadId : null,
        failure: null,
      );
    }
    if (hits.length == 1) {
      final only = hits.single;
      final spoken = hint ?? '';
      final exact =
          spoken.isNotEmpty &&
          isExactContactNameMatch(spoken, only.contact.name);
      return (
        hits: hits,
        id: exact ? only.contact.id : null,
        failure: null,
      );
    }
    if (payloadId.isEmpty) {
      return (hits: const <ContactSearchHit>[], id: null, failure: null);
    }

    final byId = await ref
        .read(getContactByIdUseCaseProvider)
        .execute(payloadId);
    final contact = byId.getRight().toNullable();
    if (contact == null) {
      return (hits: const <ContactSearchHit>[], id: null, failure: null);
    }
    return (
      hits: [_hitFor(contact)],
      id: contact.id,
      failure: null,
    );
  }

  static ContactSearchHit _hitFor(Contact contact) {
    return ContactSearchHit(
      contact: contact,
      ledgerName: '',
      isLedgerUserArchived: false,
    );
  }

  Future<AskBooksAnswer?> _askFromParseGoal(
    String goalText,
    AgentTurnResult turn,
  ) async {
    for (final proposal in turn.proposals) {
      final payload = proposal.payload;
      if (payload is! ParseGoalPayload) {
        continue;
      }
      if (payload.goalClass.trim() != 'ask') {
        continue;
      }
      final result = await ref
          .read(answerAskBooksUseCaseProvider)
          .execute(
            goalText: goalText,
            forceAsk: true,
            nameHint: payload.notes,
            lastContactId: state.lastAskContactId,
          );
      return result.getRight().toNullable();
    }
    return null;
  }

  static String? _candidateHint(AgentProposal proposal) {
    switch (proposal.payload) {
      case ProposeCreateContactPayload(:final name):
        final trimmed = name.trim();
        return trimmed.isEmpty ? null : trimmed;
      case ProposeDebtPayload(:final contactHint, :final contactId):
        return _hintIfIdMissing(contactHint, contactId);
      case ProposePaymentPayload(:final contactHint, :final contactId):
        return _hintIfIdMissing(contactHint, contactId);
      default:
        return null;
    }
  }

  static String? _exactUniqueContactId(
    String hint,
    List<ContactSearchHit> hits,
  ) {
    if (hits.length != 1) {
      return null;
    }
    final name = hits.single.contact.name;
    if (!isExactContactNameMatch(hint, name)) {
      return null;
    }
    return hits.single.contact.id;
  }

  static String? _hintIfIdMissing(String contactHint, String? contactId) {
    final id = contactId?.trim();
    if (id != null && id.isNotEmpty) {
      return null;
    }
    return nonUuidHint(contactHint);
  }

  bool _createIfMissing(AgentProposal proposal) {
    switch (proposal.payload) {
      case ProposeDebtPayload(:final contactId):
      case ProposePaymentPayload(:final contactId):
        if (state.createNewByProposal.contains(proposal.proposalId)) {
          return true;
        }
        final picked = state.contactIdByProposal[proposal.proposalId]?.trim();
        if (picked != null && picked.isNotEmpty) {
          return false;
        }
        final id = contactId?.trim();
        if (id != null && id.isNotEmpty) {
          return false;
        }
        final candidates =
            state.candidatesByProposal[proposal.proposalId] ??
            const <ContactSearchHit>[];
        return candidates.isEmpty;
      default:
        return false;
    }
  }

  static String? _contactIdFromAsk(AskBooksAnswer? answer) {
    return switch (answer) {
      AskBooksNamedBalance(:final row) => row.contactId,
      AskBooksLastTransaction(:final contactId) => contactId,
      AskBooksNoLastTransaction(:final contactId) => contactId,
      _ => null,
    };
  }

  static Map<String, int> _spokenAmounts(
    AgentTurnResult turn,
    String goalText,
  ) {
    final siblingHints = <String>[
      for (final proposal in turn.proposals)
        if (proposal.payload
            case ProposeDebtPayload(:final contactHint) ||
                ProposePaymentPayload(:final contactHint))
          contactHint,
    ];
    final amounts = <String, int>{};
    for (final proposal in turn.proposals) {
      switch (proposal.payload) {
        case ProposeDebtPayload(
              :final amountMinor,
              :final currencyCode,
              :final contactHint,
            ) ||
            ProposePaymentPayload(
              :final amountMinor,
              :final currencyCode,
              :final contactHint,
            ):
          amounts[proposal.proposalId] = correctSpokenAmountMinor(
            goalText: goalText,
            currencyCode: currencyCode,
            amountMinor: amountMinor,
            contactHint: contactHint,
            siblingHints: siblingHints,
          );
        default:
          break;
      }
    }
    return amounts;
  }
}
