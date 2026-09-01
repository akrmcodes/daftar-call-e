import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/application/agent/append_agent_turn_use_case.dart';
import 'package:daftar/application/agent/run_closing_agent_turn_use_case.dart';
import 'package:daftar/application/agent/start_agent_session_use_case.dart';
import 'package:daftar/application/ai/get_active_voice_context_use_case.dart';
import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/data/datasources/remote/closing_agent_remote_ds.dart';
import 'package:daftar/data/repositories/closing_agent_runtime_repository_impl.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/entities/agent_session.dart';
import 'package:daftar/domain/entities/agent_turn.dart';
import 'package:daftar/domain/entities/app_settings.dart';
import 'package:daftar/domain/entities/ledger.dart';
import 'package:daftar/domain/enums/agent_session_mode.dart';
import 'package:daftar/domain/enums/agent_session_status.dart';
import 'package:daftar/domain/enums/agent_turn_confirm_state.dart';
import 'package:daftar/domain/enums/agent_turn_role.dart';
import 'package:daftar/domain/repositories/agent_session_repository.dart';
import 'package:daftar/domain/repositories/agent_turn_repository.dart';
import 'package:daftar/domain/repositories/closing_agent_runtime_repository.dart';
import 'package:daftar/domain/repositories/ledger_repository.dart';
import 'package:daftar/domain/repositories/settings_repository.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:daftar/domain/value_objects/voice_entity_resolution_entry.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockLedgerRepository extends Mock implements LedgerRepository {}

class MockGetActiveVoiceContextUseCase extends Mock
    implements GetActiveVoiceContextUseCase {}

class MockAgentSessionRepository extends Mock
    implements AgentSessionRepository {}

class MockAgentTurnRepository extends Mock implements AgentTurnRepository {}

class MockClosingAgentRuntimeRepository extends Mock
    implements ClosingAgentRuntimeRepository {}

void main() {
  setUpAll(() {
    DeviceIdentity.initializeForTest('test-device-id');
    registerFallbackValue(
      const DeviceAgentRequest(
        correlationId: 'fallback-correlation',
        locale: 'ar',
        merchantLocalDay: '2026-08-13',
        ledgers: [],
        voiceHints: [],
        isMultiCurrencyEnabled: false,
        defaultCurrency: 'YER',
        goalText: 'fallback',
      ),
    );
    registerFallbackValue(
      AgentSession(
        id: 'fallback-session-id',
        mode: AgentSessionMode.capture,
        status: AgentSessionStatus.active,
        startedAt: DateTime.utc(2026, 8, 13),
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(
      AgentTurn(
        id: 'fallback-turn-id',
        sessionId: 'fallback-session-id',
        role: AgentTurnRole.user,
        confirmState: AgentTurnConfirmState.none,
        createdAt: DateTime.utc(2026, 8, 13),
        updatedAt: DateTime.utc(2026, 8, 13),
      ),
    );
    registerFallbackValue(AgentSessionMode.capture);
    registerFallbackValue(AgentTurnConfirmState.confirmed);
    registerFallbackValue(
      AgentAudioClip(bytes: Uint8List.fromList(const [0])),
    );
  });

  group('RunClosingAgentTurnUseCase', () {
    test('rejects empty goalText', () async {
      final useCase = RunClosingAgentTurnUseCase(
        settingsRepository: MockSettingsRepository(),
        ledgerRepository: MockLedgerRepository(),
        getActiveVoiceContextUseCase: MockGetActiveVoiceContextUseCase(),
        agentSessionRepository: MockAgentSessionRepository(),
        startAgentSessionUseCase: StartAgentSessionUseCase(
          MockAgentSessionRepository(),
        ),
        appendAgentTurnUseCase: AppendAgentTurnUseCase(
          MockAgentTurnRepository(),
        ),
        closingAgentRuntimeRepository: MockClosingAgentRuntimeRepository(),
      );

      final result = await useCase.execute(goalText: '   ');
      expect(result.getLeft().toNullable(), isA<ValidationFailure>());
      expect(result.getLeft().toNullable()?.code, 'goal_text_required');
    });

    test('clip plus empty text is valid and sets inline audioRef', () async {
      final settingsRepository = MockSettingsRepository();
      final ledgerRepository = MockLedgerRepository();
      final voiceUseCase = MockGetActiveVoiceContextUseCase();
      final sessionRepository = MockAgentSessionRepository();
      final turnRepository = MockAgentTurnRepository();
      final runtimeRepository = MockClosingAgentRuntimeRepository();

      when(settingsRepository.get).thenAnswer(
        (_) async => const Right(
          AppSettings(googleAccountId: 'gid-1', locale: 'en'),
        ),
      );
      when(ledgerRepository.watchAll).thenAnswer(
        (_) => Stream<List<Ledger>>.value(const []),
      );
      when(voiceUseCase.execute).thenAnswer(
        (_) async => const Right(<VoiceEntityResolutionEntry>[]),
      );
      when(
        () => sessionRepository.findActive(mode: AgentSessionMode.capture),
      ).thenAnswer(
        (_) async => Right(
          AgentSession(
            id: 'session-1',
            mode: AgentSessionMode.capture,
            status: AgentSessionStatus.active,
            startedAt: DateTime.utc(2026, 8, 13),
            createdAt: DateTime.utc(2026, 8, 13),
            updatedAt: DateTime.utc(2026, 8, 13),
          ),
        ),
      );
      when(
        () => runtimeRepository.createOrUpdateSession(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => turnRepository.append(any()),
      ).thenAnswer((invocation) async {
        return Right(invocation.positionalArguments.first as AgentTurn);
      });
      when(
        () => runtimeRepository.runTurn(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
          context: any(named: 'context'),
          audio: any(named: 'audio'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          AgentTurnResult(
            correlationId: 'corr-voice',
            sessionId: 'session-1',
            proposals: [],
            narrative: 'Mohamed owes 500.',
          ),
        ),
      );

      final useCase = RunClosingAgentTurnUseCase(
        settingsRepository: settingsRepository,
        ledgerRepository: ledgerRepository,
        getActiveVoiceContextUseCase: voiceUseCase,
        agentSessionRepository: sessionRepository,
        startAgentSessionUseCase: StartAgentSessionUseCase(sessionRepository),
        appendAgentTurnUseCase: AppendAgentTurnUseCase(turnRepository),
        closingAgentRuntimeRepository: runtimeRepository,
      );

      final clip = AgentAudioClip(
        bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      );
      final result = await useCase.execute(goalText: '  ', audioClip: clip);
      expect(result.isRight(), isTrue);

      final captured = verify(
        () => runtimeRepository.runTurn(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
          context: captureAny(named: 'context'),
          audio: captureAny(named: 'audio'),
        ),
      ).captured;
      final context = captured[0] as DeviceAgentRequest;
      final sentClip = captured[1] as AgentAudioClip;
      expect(context.goalText, ClosingAgentConstants.voiceGoalSentinel);
      expect(context.audioRef, ClosingAgentConstants.inlineAudioRefWav);
      expect(sentClip.bytes, clip.bytes);
    });

    test('maps AuthFailure from runtime (Dio 401 path)', () async {
      final settingsRepository = MockSettingsRepository();
      final ledgerRepository = MockLedgerRepository();
      final voiceUseCase = MockGetActiveVoiceContextUseCase();
      final sessionRepository = MockAgentSessionRepository();
      final turnRepository = MockAgentTurnRepository();
      final runtimeRepository = MockClosingAgentRuntimeRepository();

      when(settingsRepository.get).thenAnswer(
        (_) async => const Right(
          AppSettings(googleAccountId: 'gid-1', locale: 'en'),
        ),
      );
      when(ledgerRepository.watchAll).thenAnswer(
        (_) => Stream<List<Ledger>>.value(const []),
      );
      when(voiceUseCase.execute).thenAnswer(
        (_) async => const Right(<VoiceEntityResolutionEntry>[]),
      );
      when(
        () => sessionRepository.findActive(mode: AgentSessionMode.capture),
      ).thenAnswer(
        (_) async => Right(
          AgentSession(
            id: 'session-1',
            mode: AgentSessionMode.capture,
            status: AgentSessionStatus.active,
            startedAt: DateTime.utc(2026, 8, 13),
            createdAt: DateTime.utc(2026, 8, 13),
            updatedAt: DateTime.utc(2026, 8, 13),
          ),
        ),
      );
      when(
        () => runtimeRepository.createOrUpdateSession(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
          context: any(named: 'context'),
        ),
      ).thenAnswer((_) async => const Right(unit));
      when(
        () => turnRepository.append(any()),
      ).thenAnswer((invocation) async {
        return Right(invocation.positionalArguments.first as AgentTurn);
      });
      when(
        () => runtimeRepository.runTurn(
          userId: any(named: 'userId'),
          sessionId: any(named: 'sessionId'),
          context: any(named: 'context'),
          audio: any(named: 'audio'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          AuthFailure('unauthorized', code: 'unauthorized'),
        ),
      );

      final useCase = RunClosingAgentTurnUseCase(
        settingsRepository: settingsRepository,
        ledgerRepository: ledgerRepository,
        getActiveVoiceContextUseCase: voiceUseCase,
        agentSessionRepository: sessionRepository,
        startAgentSessionUseCase: StartAgentSessionUseCase(sessionRepository),
        appendAgentTurnUseCase: AppendAgentTurnUseCase(turnRepository),
        closingAgentRuntimeRepository: runtimeRepository,
      );

      final result = await useCase.execute(goalText: 'Mohamed owes 500');
      expect(result.getLeft().toNullable(), isA<AuthFailure>());
      expect(result.getLeft().toNullable()?.code, 'unauthorized');
    });
  });

  group('ClosingAgentRemoteDs', () {
    test(
      'POST /run sends matching goalText, daftarContext, and Bearer token',
      () async {
        final adapter = _RecordingAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = ClosingAgentRemoteDs(
          dio: dio,
          baseUrl: 'https://agent.test',
          readIdToken: ({required allowInteractive}) async => 'test-id-token',
        );

        const goalText = 'Mohamed owes 500';
        const context = DeviceAgentRequest(
          correlationId: 'corr-1',
          locale: 'en',
          merchantLocalDay: '2026-08-13',
          ledgers: [AgentLedgerRef(id: 'ledger-1', name: 'Customers')],
          voiceHints: [
            AgentVoiceHint(displayName: 'Mohamed', contactId: 'contact-1'),
          ],
          isMultiCurrencyEnabled: false,
          defaultCurrency: 'YER',
          goalText: goalText,
        );

        final result = await ds.runTurn(
          userId: 'gid-1',
          sessionId: 'session-1',
          context: context,
        );

        expect(adapter.lastMethod, 'POST');
        expect(adapter.lastPath, '/run');
        expect(adapter.lastAuthorization, 'Bearer test-id-token');
        final body = adapter.lastJsonBody!;
        final newMessage = body['newMessage']! as Map;
        final parts = newMessage['parts']! as List<dynamic>;
        expect(parts, hasLength(1));
        final firstPart = parts.first as Map;
        expect(firstPart['text'], goalText);
        expect(firstPart.containsKey('inlineData'), isFalse);
        final stateDelta = body['stateDelta']! as Map;
        final daftarContext = stateDelta['daftarContext']! as Map;
        expect(daftarContext['goalText'], goalText);
        expect(daftarContext['correlationId'], 'corr-1');
        expect(result.proposals, hasLength(1));
        expect(result.proposals.single.payload, isA<ProposeDebtPayload>());
        expect(
          (result.proposals.single.payload as ProposeDebtPayload).amountMinor,
          500,
        );
        expect(result.modelId, ClosingAgentConstants.modelId);
        expect(result.modelId, 'gemini-3.5-flash');
        expect(result.toolNames, ['propose_debt']);
        expect(result.latencyMs, isNotNull);
        expect(result.latencyMs, greaterThanOrEqualTo(0));
      },
    );

    test(
      'POST /run includes inlineData when clip present; bytes stay out of daftarContext',
      () async {
        final adapter = _RecordingAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final ds = ClosingAgentRemoteDs(
          dio: dio,
          baseUrl: 'https://agent.test',
          readIdToken: ({required allowInteractive}) async => 'test-id-token',
        );

        final clip = AgentAudioClip(
          bytes: Uint8List.fromList(const [9, 8, 7, 6]),
        );
        const context = DeviceAgentRequest(
          correlationId: 'corr-voice',
          locale: 'en',
          merchantLocalDay: '2026-08-13',
          ledgers: [AgentLedgerRef(id: 'ledger-1', name: 'Customers')],
          voiceHints: [],
          isMultiCurrencyEnabled: false,
          defaultCurrency: 'YER',
          goalText: ClosingAgentConstants.voiceGoalSentinel,
          audioRef: ClosingAgentConstants.inlineAudioRefWav,
        );

        await ds.runTurn(
          userId: 'gid-1',
          sessionId: 'session-1',
          context: context,
          audio: clip,
        );

        final body = adapter.lastJsonBody!;
        final newMessage = body['newMessage']! as Map;
        final parts = newMessage['parts']! as List<dynamic>;
        expect(parts, hasLength(2));
        expect((parts[0] as Map)['text'], '__voice__');
        final inline = (parts[1] as Map)['inlineData']! as Map;
        expect(inline['mimeType'], 'audio/wav');
        expect(inline['data'], base64Encode(clip.bytes));
        final daftarContext =
            (body['stateDelta']! as Map)['daftarContext']! as Map;
        expect(daftarContext['audioRef'], 'inline:audio/wav');
        expect(daftarContext['goalText'], '__voice__');
        expect(
          jsonEncode(daftarContext).contains(inline['data'] as String),
          isFalse,
        );
      },
    );

    test('interceptor never requests an interactive Google picker', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      var lastAllowInteractive = true;
      final ds = ClosingAgentRemoteDs(
        dio: dio,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async {
          lastAllowInteractive = allowInteractive;
          return 'test-id-token';
        },
      );

      await ds.listApps();

      expect(lastAllowInteractive, isFalse);
      expect(adapter.lastAuthorization, 'Bearer test-id-token');
    });

    test('POST /v1/tts sends locale, Bearer, and decodes MP3', () async {
      const payload = 'SUQzRkFLRS1NUDM=';
      final adapter = _TtsAdapter(
        body: jsonEncode({
          'mimeType': 'audio/mpeg',
          'audioBase64': payload,
        }),
      );
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      final clip = await ds.synthesizeSpeech(
        text: 'Mohamed owes 500',
        locale: 'en',
      );

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/v1/tts');
      expect(adapter.lastAuthorization, 'Bearer test-id-token');
      expect(adapter.lastJsonBody?['text'], 'Mohamed owes 500');
      expect(adapter.lastJsonBody?['locale'], 'en');
      expect(clip.mimeType, 'audio/mpeg');
      expect(clip.bytes, base64Decode(payload));
    });

    test('session POST 400 with sessionId in detail is success', () async {
      final adapter = _QueuedAdapter([
        _jsonResponse(
          status: 400,
          body: '{"detail":"Session already exists: session-1"}',
        ),
      ]);
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      await ds.createOrUpdateSession(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );
      await ds.createOrUpdateSession(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );

      expect(adapter.paths, hasLength(1));
      expect(adapter.paths.single, contains('/sessions/session-1'));
    });

    test('session POST 400 unrelated JSON is failure', () async {
      final adapter = _QueuedAdapter([
        _jsonResponse(
          status: 400,
          body: '{"detail":{"msg":"amount must be an integer"}}',
        ),
      ]);
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      expect(
        () => ds.createOrUpdateSession(
          userId: 'gid-1',
          sessionId: 'session-1',
          context: _sampleContext(),
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('session POST 409 is already-exists success', () async {
      final adapter = _QueuedAdapter([
        _jsonResponse(
          status: 409,
          body: '{"detail":"Session already exists: session-1"}',
        ),
      ]);
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      await ds.createOrUpdateSession(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );

      expect(adapter.paths.single, contains('/sessions/session-1'));
    });

    test('/run 404 clears warm key so create POST runs', () async {
      final adapter = _QueuedAdapter([
        _jsonResponse(status: 200, body: '{}'),
        _jsonResponse(status: 404, body: '{"detail":"Session not found"}'),
        _jsonResponse(status: 200, body: '{}'),
        _jsonResponse(
          status: 200,
          body: jsonEncode(<Map<String, Object?>>[_debtAdkEvent()]),
        ),
      ]);
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      await ds.createOrUpdateSession(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );
      await ds.createOrUpdateSession(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );

      final result = await ds.runTurn(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );

      expect(adapter.paths, [
        '/apps/closing_agent/users/gid-1/sessions/session-1',
        '/run',
        '/apps/closing_agent/users/gid-1/sessions/session-1',
        '/run',
      ]);
      expect(result.proposals, hasLength(1));
    });

    test('runTurn retries create then /run once after 404', () async {
      final adapter = _QueuedAdapter([
        _jsonResponse(status: 404, body: '{"detail":"Session not found"}'),
        _jsonResponse(status: 200, body: '{}'),
        _jsonResponse(
          status: 200,
          body: jsonEncode(<Map<String, Object?>>[_debtAdkEvent()]),
        ),
      ]);
      final ds = ClosingAgentRemoteDs(
        dio: Dio()..httpClientAdapter = adapter,
        baseUrl: 'https://agent.test',
        readIdToken: ({required allowInteractive}) async => 'test-id-token',
      );

      final result = await ds.runTurn(
        userId: 'gid-1',
        sessionId: 'session-1',
        context: _sampleContext(),
      );

      expect(adapter.paths, [
        '/run',
        '/apps/closing_agent/users/gid-1/sessions/session-1',
        '/run',
      ]);
      expect(result.proposals, hasLength(1));
    });
  });

  group('ClosingAgentRuntimeRepositoryImpl', () {
    test(
      'maps Dio 401 to agent AuthFailure, not workspace unauthorized',
      () async {
        final adapter = _StatusAdapter(401);
        final dio = Dio()..httpClientAdapter = adapter;
        final repo = ClosingAgentRuntimeRepositoryImpl(
          remoteDataSource: ClosingAgentRemoteDs(
            dio: dio,
            baseUrl: 'https://agent.test',
            readIdToken: ({required allowInteractive}) async => 'test-id-token',
          ),
        );

        final result = await repo.listApps();
        expect(result.getLeft().toNullable(), isA<AuthFailure>());
        expect(
          result.getLeft().toNullable()?.code,
          'closing_agent_unauthorized',
        );
      },
    );

    test(
      'maps Dio 403 to agent AuthFailure, not workspace ForbiddenFailure',
      () async {
        final adapter = _StatusAdapter(403);
        final dio = Dio()..httpClientAdapter = adapter;
        final repo = ClosingAgentRuntimeRepositoryImpl(
          remoteDataSource: ClosingAgentRemoteDs(
            dio: dio,
            baseUrl: 'https://agent.test',
            readIdToken: ({required allowInteractive}) async => 'test-id-token',
          ),
        );

        final result = await repo.listApps();
        final failure = result.getLeft().toNullable();
        expect(failure, isA<AuthFailure>());
        expect(failure, isNot(isA<ForbiddenFailure>()));
        expect(failure?.code, 'closing_agent_forbidden');
      },
    );

    test(
      'session POST 401 is agent AuthFailure, not already-exists',
      () async {
        final adapter = _StatusAdapter(401);
        final dio = Dio()..httpClientAdapter = adapter;
        final repo = ClosingAgentRuntimeRepositoryImpl(
          remoteDataSource: ClosingAgentRemoteDs(
            dio: dio,
            baseUrl: 'https://agent.test',
            readIdToken: ({required allowInteractive}) async => 'test-id-token',
          ),
        );

        final result = await repo.createOrUpdateSession(
          userId: 'gid-1',
          sessionId: 'session-1',
          context: _sampleContext(),
        );

        expect(result.getLeft().toNullable(), isA<AuthFailure>());
        expect(
          result.getLeft().toNullable()?.code,
          'closing_agent_unauthorized',
        );
      },
    );

    test(
      'Dio connectionError maps to closing_agent_request_failed',
      () async {
        final failure = await _repoWithAdapter(
          _DioTypeAdapter(DioExceptionType.connectionError),
        ).listApps();

        expect(failure.getLeft().toNullable(), isA<NetworkFailure>());
        expect(
          failure.getLeft().toNullable()?.code,
          'closing_agent_request_failed',
        );
        expect(
          failure.getLeft().toNullable()?.code,
          isNot(EdgeErrorCodes.serviceUnavailable),
        );
      },
    );

    test(
      'Dio connectionTimeout maps to closing_agent_request_failed',
      () async {
        final failure = await _repoWithAdapter(
          _DioTypeAdapter(DioExceptionType.connectionTimeout),
        ).listApps();

        expect(failure.getLeft().toNullable(), isA<NetworkFailure>());
        expect(
          failure.getLeft().toNullable()?.code,
          'closing_agent_request_failed',
        );
      },
    );

    test(
      'HTTP 503 maps to closing_agent_request_failed, not sync copy code',
      () async {
        final failure = await _repoWithAdapter(_StatusAdapter(503)).listApps();

        expect(failure.getLeft().toNullable(), isA<NetworkFailure>());
        expect(
          failure.getLeft().toNullable()?.code,
          'closing_agent_request_failed',
        );
      },
    );
  });
}

ClosingAgentRuntimeRepositoryImpl _repoWithAdapter(HttpClientAdapter adapter) {
  return ClosingAgentRuntimeRepositoryImpl(
    remoteDataSource: ClosingAgentRemoteDs(
      dio: Dio()..httpClientAdapter = adapter,
      baseUrl: 'https://agent.test',
      readIdToken: ({required allowInteractive}) async => 'test-id-token',
    ),
  );
}

class _TtsAdapter implements HttpClientAdapter {
  _TtsAdapter({required this.body});

  final String body;
  String? lastMethod;
  String? lastPath;
  String? lastAuthorization;
  Map<String, Object?>? lastJsonBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.uri.path;
    lastAuthorization =
        options.headers['Authorization'] as String? ??
        options.headers['authorization'] as String?;
    if (requestStream != null) {
      final builder = BytesBuilder(copy: false);
      await requestStream.forEach(builder.add);
      final raw = utf8.decode(builder.takeBytes());
      if (raw.isNotEmpty) {
        lastJsonBody = Map<String, Object?>.from(jsonDecode(raw) as Map);
      }
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  String? lastMethod;
  String? lastPath;
  String? lastAuthorization;
  Map<String, Object?>? lastJsonBody;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.uri.path;
    lastAuthorization =
        options.headers['Authorization'] as String? ??
        options.headers['authorization'] as String?;
    if (requestStream != null) {
      final builder = BytesBuilder(copy: false);
      await requestStream.forEach(builder.add);
      final raw = utf8.decode(builder.takeBytes());
      if (raw.isNotEmpty) {
        lastJsonBody = Map<String, Object?>.from(jsonDecode(raw) as Map);
      }
    }
    return ResponseBody.fromString(
      jsonEncode(<Map<String, Object?>>[_debtAdkEvent()]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _QueuedAdapter implements HttpClientAdapter {
  _QueuedAdapter(this._bodies);

  final List<ResponseBody> _bodies;
  final List<String> paths = [];
  var _index = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    paths.add(options.uri.path);
    if (_index >= _bodies.length) {
      throw StateError('No queued response for ${options.uri.path}');
    }
    return _bodies[_index++];
  }
}

ResponseBody _jsonResponse({required int status, required String body}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

DeviceAgentRequest _sampleContext() {
  return const DeviceAgentRequest(
    correlationId: 'corr-1',
    locale: 'en',
    merchantLocalDay: '2026-08-13',
    ledgers: [AgentLedgerRef(id: 'ledger-1', name: 'Customers')],
    voiceHints: [
      AgentVoiceHint(displayName: 'Mohamed', contactId: 'contact-1'),
    ],
    isMultiCurrencyEnabled: false,
    defaultCurrency: 'YER',
    goalText: 'Mohamed owes 500',
  );
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return ResponseBody.fromString(
      'Unauthorized',
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }
}

class _DioTypeAdapter implements HttpClientAdapter {
  _DioTypeAdapter(this.type);

  final DioExceptionType type;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    throw DioException(requestOptions: options, type: type);
  }
}

Map<String, Object?> _debtAdkEvent() {
  return <String, Object?>{
    'content': <String, Object?>{
      'role': 'model',
      'parts': <Object?>[
        <String, Object?>{
          'functionResponse': <String, Object?>{
            'name': 'propose_debt',
            'response': <String, Object?>{
              'proposalId': '11111111-1111-4111-8111-111111111111',
              'tool': 'propose_debt',
              'payload': <String, Object?>{
                'contactHint': 'Mohamed',
                'amountMinor': 500,
                'currencyCode': 'YER',
              },
              'confirmRequired': true,
            },
          },
        },
      ],
    },
  };
}
