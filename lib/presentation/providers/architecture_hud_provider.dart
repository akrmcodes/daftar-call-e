import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/enums/collections_call_row_status.dart';
import 'package:daftar/domain/enums/collections_desk_row_status.dart';
import 'package:daftar/domain/enums/proposal_tool.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/ask_books_answer.dart';
import 'package:daftar/domain/value_objects/collections_call_progress.dart';
import 'package:daftar/domain/value_objects/collections_desk_row.dart';
import 'package:daftar/presentation/providers/closing_agent_controller.dart';
import 'package:daftar/presentation/providers/closing_agent_state.dart';
import 'package:daftar/presentation/providers/core_providers.dart';
import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'architecture_hud_provider.g.dart';

/// HITL architecture stations shown on the contest HUD rail.
enum ArchitectureHudHitlStep {
  /// Cloud Run `/run` in flight — Gemini proposes.
  propose,

  /// Merchant reviews proposals or desk send rows.
  confirm,

  /// Device Drift commit / close-the-day ritual.
  commit,

  /// FIFO aging ranked Collections Desk.
  rank,
}

/// Last-turn tool family for HUD scoping (not SequentialAgent routing).
enum ArchitectureHudToolScope {
  /// Mid-day capture tools (`propose_debt`, etc.).
  capture,

  /// Close-day tools (`propose_closing_plan`, etc.).
  close,

  /// Device-local Ask Books (no `/run`).
  ask,

  /// No scoped tools yet.
  none,
}

/// Presentation snapshot for the contest Architecture HUD overlay.
class ArchitectureHudSnapshot extends Equatable {
  /// Creates a HUD snapshot.
  const ArchitectureHudSnapshot({
    required this.enabled,
    this.phase = ClosingAgentPhase.idle,
    this.isRunning = false,
    this.modelId,
    this.toolNames = const [],
    this.toolScope = ArchitectureHudToolScope.none,
    this.latencyMs,
    this.correlationId,
    this.hitlStep = ArchitectureHudHitlStep.propose,
    this.pendingCount = 0,
    this.committedCount = 0,
    this.skippedCount = 0,
    this.deskPendingCount = 0,
    this.deskSentCount = 0,
    this.smtpMessageId,
    this.callRunId,
    this.callStatus,
  });

  /// Maps settings + Closing Agent state. Does not read Cloud Logging.
  factory ArchitectureHudSnapshot.fromAgent({
    required bool enabled,
    ClosingAgentPhase phase = ClosingAgentPhase.idle,
    AgentTurnResult? turnResult,
    AskBooksAnswer? askAnswer,
    Set<String> committedIds = const {},
    Set<String> skippedIds = const {},
    int pendingConfirmableCount = 0,
    bool hasPendingClosingPlan = false,
    bool collectionsDispatching = false,
    List<CollectionsDeskRow> deskRows = const [],
    CollectionsCallProgress? callProgress,
  }) {
    if (!enabled) {
      return const ArchitectureHudSnapshot(enabled: false);
    }

    final toolNames = turnResult?.toolNames ?? const <String>[];
    final deskPendingCount = deskRows
        .where((row) => row.status == CollectionsDeskRowStatus.pending)
        .length;
    final deskSentCount = deskRows.where((row) => row.isAcceptedSend).length;

    String? smtpMessageId;
    for (final row in deskRows) {
      if (row.isAcceptedSend) {
        smtpMessageId = row.smtpMessageId;
      }
    }

    final callChip = resolveCallChip(callProgress);

    return ArchitectureHudSnapshot(
      enabled: true,
      phase: phase,
      isRunning: phase == ClosingAgentPhase.running,
      modelId: turnResult?.modelId ?? ClosingAgentConstants.modelId,
      toolNames: toolNames,
      toolScope: resolveToolScope(askAnswer: askAnswer, toolNames: toolNames),
      latencyMs: turnResult?.latencyMs,
      correlationId: turnResult?.correlationId,
      hitlStep: resolveHitlStep(
        phase: phase,
        pendingConfirmableCount: pendingConfirmableCount,
        hasPendingClosingPlan: hasPendingClosingPlan,
        committedIds: committedIds,
        deskPendingCount: deskPendingCount,
        collectionsDispatching: collectionsDispatching,
      ),
      pendingCount: pendingConfirmableCount + (hasPendingClosingPlan ? 1 : 0),
      committedCount: committedIds.length,
      skippedCount: skippedIds.length,
      deskPendingCount: deskPendingCount,
      deskSentCount: deskSentCount,
      smtpMessageId: smtpMessageId,
      callRunId: callChip.runId,
      callStatus: callChip.status,
    );
  }

  /// Settings toggle. Overlay is hidden when false.
  final bool enabled;

  /// Current Closing Agent phase.
  final ClosingAgentPhase phase;

  /// Whether Cloud Run `/run` is in flight.
  final bool isRunning;

  /// Pinned `/run` model id (`gemini-3.5-flash`).
  final String? modelId;

  /// Ordered unique ADK tool wire names from the last turn.
  final List<String> toolNames;

  /// Scoped tool family for the last turn / Ask Books path.
  final ArchitectureHudToolScope toolScope;

  /// Cloud Run `/run` round-trip milliseconds as measured on device.
  final int? latencyMs;

  /// Device-generated correlation id (HUD shows last-8).
  final String? correlationId;

  /// Live HITL station on the architecture rail.
  final ArchitectureHudHitlStep hitlStep;

  /// Pending confirmable proposals (+ closing plan when present).
  final int pendingCount;

  /// Device-committed proposal ids.
  final int committedCount;

  /// Skipped proposal ids.
  final int skippedCount;

  /// Collections Desk rows awaiting merchant send.
  final int deskPendingCount;

  /// Collections Desk rows with SMTP 250 + Message-ID.
  final int deskSentCount;

  /// Last accepted send-batch Message-ID (SMTP 250). Never a delivery id.
  final String? smtpMessageId;

  /// CALL-E `call.id` for the HUD chip (last row with a run id wins).
  final String? callRunId;

  /// HUD call status (`planned` / `ringing` / `completed` / `failed`).
  final CollectionsCallRowStatus? callStatus;

  /// Whether the instrument should render (enabled only — not chip-empty).
  bool get visible => enabled;

  /// Resolves the live HITL rail station from Closing Agent state.
  static ArchitectureHudHitlStep resolveHitlStep({
    required ClosingAgentPhase phase,
    required int pendingConfirmableCount,
    required bool hasPendingClosingPlan,
    required Set<String> committedIds,
    required int deskPendingCount,
    required bool collectionsDispatching,
  }) {
    if (phase == ClosingAgentPhase.running) {
      return ArchitectureHudHitlStep.propose;
    }
    if (pendingConfirmableCount > 0 || hasPendingClosingPlan) {
      return ArchitectureHudHitlStep.confirm;
    }
    if (phase == ClosingAgentPhase.ritualRunning) {
      return ArchitectureHudHitlStep.commit;
    }
    if (phase == ClosingAgentPhase.ritualDesk) {
      if (deskPendingCount > 0 && !collectionsDispatching) {
        return ArchitectureHudHitlStep.confirm;
      }
      return ArchitectureHudHitlStep.rank;
    }
    if (committedIds.isNotEmpty) {
      return ArchitectureHudHitlStep.commit;
    }
    return ArchitectureHudHitlStep.propose;
  }

  /// Resolves tool scope from Ask Books or last `/run` tool names.
  static ArchitectureHudToolScope resolveToolScope({
    AskBooksAnswer? askAnswer,
    List<String> toolNames = const [],
  }) {
    if (askAnswer != null) {
      return ArchitectureHudToolScope.ask;
    }
    for (final name in toolNames) {
      if (name == ProposalTool.proposeClosingPlan.wireName ||
          name == ProposalTool.proposeWhatsappDrafts.wireName) {
        return ArchitectureHudToolScope.close;
      }
    }
    for (final name in toolNames) {
      if (name == ProposalTool.proposeDebt.wireName ||
          name == ProposalTool.proposePayment.wireName ||
          name == ProposalTool.proposeCreateContact.wireName ||
          name == ProposalTool.proposeCreateLedger.wireName ||
          name == ProposalTool.proposeStatement.wireName) {
        return ArchitectureHudToolScope.capture;
      }
    }
    return ArchitectureHudToolScope.none;
  }

  /// Resolves the call chip from device call progress (last `runId` wins).
  ///
  /// When progress exists but `runId` is not yet assigned, still returns
  /// the latest status so `planned` can show before `run-batch` returns.
  static ({String? runId, CollectionsCallRowStatus? status}) resolveCallChip(
    CollectionsCallProgress? callProgress,
  ) {
    if (callProgress == null || callProgress.results.isEmpty) {
      return (runId: null, status: null);
    }

    String? runId;
    CollectionsCallRowStatus? status;
    for (final row in callProgress.results) {
      status = row.status;
      final trimmed = row.runId?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        runId = trimmed;
      }
    }
    return (runId: runId, status: status);
  }

  /// Last 8 characters of [raw] for HUD chips.
  ///
  /// Trims, strips wrapping `<>`, uses the local-part when `@` is present,
  /// then takes the tail. UUIDs have no `@` so the raw tail is used.
  static String? tail8(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    if (value.length >= 2 && value.startsWith('<') && value.endsWith('>')) {
      value = value.substring(1, value.length - 1);
    }
    final at = value.indexOf('@');
    if (at > 0) {
      value = value.substring(0, at);
    }
    if (value.isEmpty) {
      return null;
    }
    if (value.length <= 8) {
      return value;
    }
    return value.substring(value.length - 8);
  }

  @override
  List<Object?> get props => [
    enabled,
    phase,
    isRunning,
    modelId,
    toolNames,
    toolScope,
    latencyMs,
    correlationId,
    hitlStep,
    pendingCount,
    committedCount,
    skippedCount,
    deskPendingCount,
    deskSentCount,
    smtpMessageId,
    callRunId,
    callStatus,
  ];
}

/// Reads the HUD toggle and last Closing Agent turn / send-batch ids.
@riverpod
ArchitectureHudSnapshot architectureHudSnapshot(Ref ref) {
  final enabled =
      ref.watch(appSettingsProvider).asData?.value.demoArchitectureHud ??
      false;
  if (!enabled) {
    return const ArchitectureHudSnapshot(enabled: false);
  }
  final agent = ref.watch(closingAgentControllerProvider);
  return ArchitectureHudSnapshot.fromAgent(
    enabled: true,
    phase: agent.phase,
    turnResult: agent.turnResult,
    askAnswer: agent.askAnswer,
    committedIds: agent.committedIds,
    skippedIds: agent.skippedIds,
    pendingConfirmableCount: agent.pendingConfirmable.length,
    hasPendingClosingPlan: agent.pendingClosingPlan != null,
    collectionsDispatching: agent.collectionsDispatching,
    deskRows: agent.deskRows,
    callProgress: agent.callProgress,
  );
}
