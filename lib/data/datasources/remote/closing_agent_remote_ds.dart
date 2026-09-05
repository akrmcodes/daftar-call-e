import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/data/mappers/adk_event_proposal_mapper.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/value_objects/agent_audio_clip.dart';
import 'package:daftar/domain/value_objects/agent_proposal.dart';
import 'package:daftar/domain/value_objects/agent_speech_clip.dart';
import 'package:daftar/domain/value_objects/agent_turn_result.dart';
import 'package:daftar/domain/value_objects/call_get_result.dart';
import 'package:daftar/domain/value_objects/call_plan_batch.dart';
import 'package:daftar/domain/value_objects/call_run_batch.dart';
import 'package:daftar/domain/value_objects/device_agent_request.dart';
import 'package:daftar/domain/value_objects/email_send_batch.dart';
import 'package:dio/dio.dart';

/// Reads a Google ID token for Cloud Run IAM (audience = custom / service URL).
typedef ClosingAgentIdTokenReader =
    Future<String?> Function({required bool allowInteractive});

/// Dio client for ADK-native Cloud Run endpoints (Appendix J.6).
///
/// Never logs `Authorization`. Timeouts are longer than the shared sync Dio
/// because Vertex + min-instances 0 can exceed 15s.
class ClosingAgentRemoteDs {
  /// Creates the remote data source.
  ClosingAgentRemoteDs({
    required Dio dio,
    required ClosingAgentIdTokenReader readIdToken,
    String? baseUrl,
  }) : _dio = dio,
       _readIdToken = readIdToken,
       _baseUrl = _normalizeBaseUrl(baseUrl ?? Env.closingAgentBaseUrl) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await _readIdToken(allowInteractive: false);
            if (token == null || token.isEmpty) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  error: const AuthException(
                    'Google ID token unavailable for Closing Agent.',
                  ),
                ),
              );
              return;
            }
            options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } on Object catch (error, stackTrace) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        },
      ),
    );
  }

  final Dio _dio;
  final ClosingAgentIdTokenReader _readIdToken;
  final String _baseUrl;

  /// Process-local sessions already created on this Cloud Run instance.
  /// Keyed by `userId + sessionId`. Cleared when `/run` returns 404.
  final Set<String> _ensuredSessions = <String>{};

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  Options get _jsonOptions => Options(
    headers: const {'Content-Type': 'application/json'},
    responseType: ResponseType.json,
    sendTimeout: ClosingAgentConstants.sendTimeout,
    receiveTimeout: ClosingAgentConstants.receiveTimeout,
  );

  /// `GET /list-apps`.
  Future<List<String>> listApps() async {
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/list-apps',
        options: _jsonOptions,
      );
      final data = response.data;
      if (data is! List<dynamic>) {
        throw const ServerException(
          'list-apps response was not a JSON array.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return [
        for (final item in data)
          if (item is String && item.isNotEmpty) item,
      ];
    } on DioException catch (error) {
      throw _mapDio(error, 'Closing Agent list-apps failed.');
    }
  }

  /// `POST /apps/{app}/users/{userId}/sessions/{sessionId}`.
  ///
  /// ADK InMemorySessionService treats POST as create-only. Skip HTTP when
  /// this process already ensured the session. Otherwise 409 is success; 400
  /// is success only when FastAPI `detail` contains the posted `sessionId`.
  Future<void> createOrUpdateSession({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
  }) async {
    final key = _sessionKey(userId, sessionId);
    if (_ensuredSessions.contains(key)) {
      return;
    }
    try {
      await _postCreateSession(
        userId: userId,
        sessionId: sessionId,
        context: context,
      );
      _ensuredSessions.add(key);
    } on DioException catch (error) {
      if (_isSessionAlreadyExists(error, sessionId)) {
        _ensuredSessions.add(key);
        return;
      }
      throw _mapDio(error, 'Closing Agent session create failed.');
    }
  }

  /// `POST /run` and parse Appendix J proposals from ADK events.
  ///
  /// If the in-memory session was lost (scale-to-zero → 404), create once
  /// and retry `/run` once.
  Future<AgentTurnResult> runTurn({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
    AgentAudioClip? audio,
  }) async {
    try {
      return await _postRun(
        userId: userId,
        sessionId: sessionId,
        context: context,
        audio: audio,
      );
    } on ProposalParseException {
      rethrow;
    } on DioException catch (error) {
      if (!_isNotFound(error)) {
        throw _mapDio(error, 'Closing Agent /run failed.');
      }
      _ensuredSessions.remove(_sessionKey(userId, sessionId));
      await createOrUpdateSession(
        userId: userId,
        sessionId: sessionId,
        context: context,
      );
      try {
        return await _postRun(
          userId: userId,
          sessionId: sessionId,
          context: context,
          audio: audio,
        );
      } on ProposalParseException {
        rethrow;
      } on DioException catch (retryError) {
        throw _mapDio(retryError, 'Closing Agent /run failed.');
      }
    }
  }

  /// `POST /v1/email/send-batch` — multipart J.7. Never sets JSON Content-Type.
  ///
  /// Never sends or logs an App Password.
  Future<EmailSendBatchResponse> sendEmailBatch(
    EmailSendBatchRequest request,
  ) async {
    try {
      final form = FormData();
      form.fields.add(
        MapEntry('manifest', jsonEncode(request.manifestJson())),
      );
      for (final recipient in request.recipients) {
        final bytes = request.pdfsByContactId[recipient.contactId];
        if (bytes == null) {
          continue;
        }
        form.files.add(
          MapEntry(
            'pdf_${recipient.contactId}',
            MultipartFile.fromBytes(
              bytes,
              filename: recipient.filename ?? 'daftar-statement.pdf',
            ),
          ),
        );
      }
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/email/send-batch',
        data: form,
        options: Options(
          sendTimeout: ClosingAgentConstants.emailSendBatchSendTimeout,
          receiveTimeout: ClosingAgentConstants.emailSendBatchReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          'send-batch response was not a JSON object.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return EmailSendBatchResponse.fromJson(
        Map<String, Object?>.from(data),
      );
    } on DioException catch (error) {
      throw _mapDio(error, 'Closing Agent send-batch failed.');
    }
  }

  Options get _callJsonOptions => Options(
    headers: const {'Content-Type': 'application/json'},
    responseType: ResponseType.json,
    sendTimeout: ClosingAgentConstants.sendTimeout,
    receiveTimeout: ClosingAgentConstants.callBatchReceiveTimeout,
  );

  /// `POST /v1/calls/plan-batch`. Never logs confirm handles or E.164.
  Future<CallPlanBatchResponse> planCallBatch(
    CallPlanBatchRequest request,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/calls/plan-batch',
        data: request.toJson(),
        options: _callJsonOptions,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          'plan-batch response was not a JSON object.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return CallPlanBatchResponse.fromJson(Map<String, Object?>.from(data));
    } on DioException catch (error) {
      throw _mapCallDio(error, 'Closing Agent plan-batch failed.');
    }
  }

  /// `POST /v1/calls/run-batch`. Never logs confirm handles or E.164.
  Future<CallRunBatchResponse> runCallBatch(
    CallRunBatchRequest request,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/calls/run-batch',
        data: request.toJson(),
        options: _callJsonOptions,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          'run-batch response was not a JSON object.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return CallRunBatchResponse.fromJson(Map<String, Object?>.from(data));
    } on DioException catch (error) {
      throw _mapCallDio(error, 'Closing Agent run-batch failed.');
    }
  }

  /// `GET /v1/calls/{runId}`. [runId] is CALL-E `call.id`.
  Future<CallGetResult> getCallRun(String runId) async {
    final encoded = Uri.encodeComponent(runId.trim());
    try {
      final response = await _dio.get<dynamic>(
        '$_baseUrl/v1/calls/$encoded',
        options: _callJsonOptions,
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          'GET call response was not a JSON object.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return CallGetResult.fromJson(Map<String, Object?>.from(data));
    } on DioException catch (error) {
      throw _mapCallDio(error, 'Closing Agent GET call failed.');
    }
  }

  /// `POST /v1/tts` — Chirp 3 HD MP3. Never logs [text] or audioBase64.
  Future<AgentSpeechClip> synthesizeSpeech({
    required String text,
    required String locale,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '$_baseUrl/v1/tts',
        data: <String, Object?>{
          'text': text,
          'locale': locale,
        },
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          sendTimeout: ClosingAgentConstants.ttsSendTimeout,
          receiveTimeout: ClosingAgentConstants.ttsReceiveTimeout,
        ),
      );
      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          'TTS response was not a JSON object.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      final mime = data['mimeType'];
      final encoded = data['audioBase64'];
      if (mime is! String ||
          mime.isEmpty ||
          encoded is! String ||
          encoded.isEmpty) {
        throw const ServerException(
          'TTS response missing audio.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) {
        throw const ServerException(
          'TTS audio was empty.',
          errorCode: EdgeErrorCodes.invalidRequest,
        );
      }
      return AgentSpeechClip(
        bytes: Uint8List.fromList(bytes),
        mimeType: mime,
      );
    } on ServerException {
      rethrow;
    } on FormatException {
      throw const ServerException(
        'TTS audio was not valid base64.',
        errorCode: EdgeErrorCodes.invalidRequest,
      );
    } on DioException catch (error) {
      throw _mapDio(error, 'Closing Agent TTS failed.');
    }
  }

  Future<void> _postCreateSession({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
  }) {
    final app = Uri.encodeComponent(ClosingAgentConstants.appName);
    final encodedUser = Uri.encodeComponent(userId);
    final encodedSession = Uri.encodeComponent(sessionId);
    return _dio.post<dynamic>(
      '$_baseUrl/apps/$app/users/$encodedUser/sessions/$encodedSession',
      data: <String, Object?>{
        'stateDelta': <String, Object?>{
          'daftarContext': context.toJson(),
        },
      },
      options: _jsonOptions,
    );
  }

  Future<AgentTurnResult> _postRun({
    required String userId,
    required String sessionId,
    required DeviceAgentRequest context,
    AgentAudioClip? audio,
  }) async {
    final parts = <Map<String, Object?>>[
      <String, Object?>{'text': context.goalText},
    ];
    if (audio != null && audio.isNotEmpty) {
      parts.add(
        <String, Object?>{
          'inlineData': <String, Object?>{
            'mimeType': audio.mimeType,
            'data': base64Encode(audio.bytes),
          },
        },
      );
    }
    final stopwatch = Stopwatch()..start();
    final response = await _dio.post<dynamic>(
      '$_baseUrl/run',
      data: <String, Object?>{
        'appName': ClosingAgentConstants.appName,
        'userId': userId,
        'sessionId': sessionId,
        'stateDelta': <String, Object?>{
          'daftarContext': context.toJson(),
        },
        'newMessage': <String, Object?>{
          'role': 'user',
          'parts': parts,
        },
      },
      options: _jsonOptions,
    );
    stopwatch.stop();
    // Never log [parts] — WAV base64 must not enter Crashlytics / developer.log.
    final events = _asEventList(response.data);
    final proposals = extractProposalsFromAdkEvents(events);
    return AgentTurnResult(
      correlationId: context.correlationId,
      sessionId: sessionId,
      proposals: proposals,
      narrative: extractNarrativeFromAdkEvents(events),
      modelId: ClosingAgentConstants.modelId,
      toolNames: _uniqueToolWireNames(proposals),
      latencyMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Ordered unique ADK tool wire names from this turn's proposals.
  static List<String> _uniqueToolWireNames(List<AgentProposal> proposals) {
    final seen = <String>{};
    final names = <String>[];
    for (final proposal in proposals) {
      final name = proposal.tool.wireName;
      if (seen.add(name)) {
        names.add(name);
      }
    }
    return names;
  }

  static String _sessionKey(String userId, String sessionId) {
    return '$userId|$sessionId';
  }

  /// 409 matches the ADK status contract. 400 matches only FastAPI
  /// `{"detail":"Session already exists: <sessionId>"}` — the UUID, not
  /// English "already exists" (that string must not drive merchant UI).
  static bool _isSessionAlreadyExists(DioException error, String sessionId) {
    if (error.type != DioExceptionType.badResponse) {
      return false;
    }
    final status = error.response?.statusCode;
    if (status == 409) {
      return true;
    }
    if (status != 400) {
      return false;
    }
    final detail = _responseDetail(error.response?.data);
    return detail != null && detail.contains(sessionId);
  }

  static String? _responseDetail(Object? data) {
    if (data is String) {
      return data;
    }
    if (data is Map) {
      final detail = data['detail'];
      return detail is String ? detail : null;
    }
    return null;
  }

  static bool _isNotFound(DioException error) {
    return error.type == DioExceptionType.badResponse &&
        error.response?.statusCode == 404;
  }

  Object _asEventList(Object? data) {
    if (data is List<dynamic>) {
      return data;
    }
    if (data is Map && data['events'] is List<dynamic>) {
      return data['events'] as List<dynamic>;
    }
    throw const ServerException(
      'ADK /run response was not an event list.',
      errorCode: EdgeErrorCodes.invalidRequest,
    );
  }

  Exception _mapCallDio(DioException error, String fallbackMessage) {
    if (error.type == DioExceptionType.badResponse &&
        error.response?.statusCode == 403) {
      final data = error.response?.data;
      if (data is Map && data['detail'] == 'killSwitch') {
        return const ServerException(
          'CALL-E kill switch',
          statusCode: 403,
          errorCode: 'calle_kill_switch',
        );
      }
    }
    return _mapDio(error, fallbackMessage);
  }

  Exception _mapDio(DioException error, String fallbackMessage) {
    final inner = error.error;
    if (inner is AuthException) {
      return inner;
    }
    if (inner is ServerException) {
      return inner;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return ServerException(
          fallbackMessage,
          errorCode: EdgeErrorCodes.serviceUnavailable,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return mapEdgeFunctionDioException(
          error,
          fallbackMessage: fallbackMessage,
        );
    }
  }
}
