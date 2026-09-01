import 'dart:convert';

import 'package:daftar/application/agent/append_agent_turn_use_case.dart';
import 'package:daftar/application/agent/start_agent_session_use_case.dart';
import 'package:daftar/application/ai/get_active_voice_context_use_case.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/core/utils/uuid_util.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:fpdart/fpdart.dart';

/// Assembles Appendix J context, runs one Cloud Run ADK turn, persists turns.
class RunClosingAgentTurnUseCase {
  /// Creates the use case.
  const RunClosingAgentTurnUseCase({
    required SettingsRepository settingsRepository,
    required LedgerRepository ledgerRepository,
    required GetActiveVoiceContextUseCase getActiveVoiceContextUseCase,
    required AgentSessionRepository agentSessionRepository,
    required StartAgentSessionUseCase startAgentSessionUseCase,
    required AppendAgentTurnUseCase appendAgentTurnUseCase,
    required ClosingAgentRuntimeRepository closingAgentRuntimeRepository,
  }) : _settingsRepository = settingsRepository,
       _ledgerRepository = ledgerRepository,
       _getActiveVoiceContextUseCase = getActiveVoiceContextUseCase,
       _agentSessionRepository = agentSessionRepository,
       _startAgentSessionUseCase = startAgentSessionUseCase,
       _appendAgentTurnUseCase = appendAgentTurnUseCase,
       _closingAgentRuntimeRepository = closingAgentRuntimeRepository;

  final SettingsRepository _settingsRepository;
  final LedgerRepository _ledgerRepository;
  final GetActiveVoiceContextUseCase _getActiveVoiceContextUseCase;
  final AgentSessionRepository _agentSessionRepository;
  final StartAgentSessionUseCase _startAgentSessionUseCase;
  final AppendAgentTurnUseCase _appendAgentTurnUseCase;
  final ClosingAgentRuntimeRepository _closingAgentRuntimeRepository;

  /// Sends [goalText] (or a WAV [audioClip]) to Cloud Run and returns proposals.
  ///
  /// Empty typed text is valid only when [audioClip] is non-empty; then
  /// `goalText` is `__voice__` and `audioRef` is `inline:audio/wav`.
  Future<Either<Failure, AgentTurnResult>> execute({
    required String goalText,
    AgentAudioClip? audioClip,
    AgentSessionMode mode = AgentSessionMode.capture,
  }) async {
    final trimmedGoal = goalText.trim();
    final hasClip = audioClip != null && audioClip.isNotEmpty;
    if (!hasClip && trimmedGoal.isEmpty) {
      return const Left(
        ValidationFailure(
          'Goal text is required.',
          code: 'goal_text_required',
        ),
      );
    }
    final resolvedGoal = hasClip
        ? ClosingAgentConstants.voiceGoalSentinel
        : trimmedGoal;

    final settingsResult = await _settingsRepository.get();
    if (settingsResult.isLeft()) {
      return Left(settingsResult.getLeft().toNullable()!);
    }
    final settings = settingsResult.getRight().toNullable()!;

    final ledgers = await _ledgerRepository.watchAll().first;
    final voiceResult = await _getActiveVoiceContextUseCase.execute();
    if (voiceResult.isLeft()) {
      return Left(voiceResult.getLeft().toNullable()!);
    }
    final voiceHints = voiceResult.getRight().toNullable()!;

    final correlationId = UuidUtil.generate();
    final context = DeviceAgentRequest(
      correlationId: correlationId,
      locale: _locale(settings.locale),
      merchantLocalDay: ClosingAgentConstants.merchantLocalDay(),
      ledgers: [
        for (final ledger in ledgers) _ledgerRef(ledger),
      ],
      voiceHints: [
        for (final hint in voiceHints)
          AgentVoiceHint(
            displayName: hint.contactName,
            contactId: hint.contactId,
          ),
      ],
      isMultiCurrencyEnabled: settings.isMultiCurrencyEnabled,
      defaultCurrency: settings.defaultCurrency,
      goalText: resolvedGoal,
      audioRef: hasClip ? ClosingAgentConstants.inlineAudioRefWav : null,
    );

    final sessionResult = await _ensureSession(
      mode: mode,
      correlationId: correlationId,
    );
    if (sessionResult.isLeft()) {
      return Left(sessionResult.getLeft().toNullable()!);
    }
    final session = sessionResult.getRight().toNullable()!;
    final userId = _adkUserId(settings);

    final createResult = await _closingAgentRuntimeRepository
        .createOrUpdateSession(
          userId: userId,
          sessionId: session.id,
          context: context,
        );
    if (createResult.isLeft()) {
      return Left(createResult.getLeft().toNullable()!);
    }

    final userTurn = await _appendAgentTurnUseCase.execute(
      sessionId: session.id,
      role: AgentTurnRole.user,
      transcript: resolvedGoal,
    );
    if (userTurn.isLeft()) {
      return Left(userTurn.getLeft().toNullable()!);
    }

    final runResult = await _closingAgentRuntimeRepository.runTurn(
      userId: userId,
      sessionId: session.id,
      context: context,
      audio: hasClip ? audioClip : null,
    );
    if (runResult.isLeft()) {
      return Left(runResult.getLeft().toNullable()!);
    }
    final turnResult = runResult.getRight().toNullable()!;

    for (final proposal in turnResult.proposals) {
      final persisted = await _appendAgentTurnUseCase.execute(
        sessionId: session.id,
        role: AgentTurnRole.tool,
        confirmState: proposal.confirmRequired
            ? AgentTurnConfirmState.pending
            : AgentTurnConfirmState.none,
        proposalJson: jsonEncode(proposal.rawEnvelope),
        proposalId: proposal.proposalId,
        toolName: proposal.tool.wireName,
      );
      if (persisted.isLeft()) {
        return Left(persisted.getLeft().toNullable()!);
      }
    }

    return Right(turnResult);
  }

  Future<Either<Failure, AgentSession>> _ensureSession({
    required AgentSessionMode mode,
    required String correlationId,
  }) async {
    final active = await _agentSessionRepository.findActive(mode: mode);
    if (active.isLeft()) {
      return Left(active.getLeft().toNullable()!);
    }
    final existing = active.getRight().toNullable();
    if (existing != null) {
      return Right(existing);
    }
    return _startAgentSessionUseCase.execute(
      mode: mode,
      correlationId: correlationId,
    );
  }

  static AgentLedgerRef _ledgerRef(Ledger ledger) {
    return AgentLedgerRef(id: ledger.id, name: ledger.name);
  }

  static String _locale(String locale) {
    final normalized = locale.trim().toLowerCase();
    if (normalized.startsWith('en')) {
      return 'en';
    }
    return 'ar';
  }

  static String _adkUserId(AppSettings settings) {
    final googleId = settings.googleAccountId?.trim();
    if (googleId != null && googleId.isNotEmpty) {
      return googleId;
    }
    return DeviceIdentity.currentOrNull ?? 'anonymous';
  }
}
