import 'dart:async';
import 'dart:convert';

import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/domain/entities/sync_operation.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote sync transport: Edge Function push/pull + Realtime wake-ups.
class SyncRemoteDs {
  /// Creates the remote data source.
  SyncRemoteDs({
    required Dio dio,
    String? functionsBaseUrl,
    String? publishableKey,
    StreamController<void>? wakeupController,
  })  : _dio = dio,
        _functionsBaseUrl = _normalizeBaseUrl(
          functionsBaseUrl ?? Env.activationApiBaseUrl,
        ),
        _publishableKey = publishableKey ?? Env.supabasePublishableKey,
        _supabaseUrl = _deriveSupabaseUrl(
          functionsBaseUrl ?? Env.activationApiBaseUrl,
        ),
        _wakeupController = wakeupController ?? StreamController<void>.broadcast();

  final Dio _dio;
  final String _functionsBaseUrl;
  final String _publishableKey;
  final String _supabaseUrl;

  SupabaseClient? _realtimeClient;
  RealtimeChannel? _channel;
  final StreamController<void> _wakeupController;
  String? _subscribedWorkspaceId;
  Future<void>? _channelSetup;

  /// Broadcast stream for postgres_changes wake-ups.
  Stream<void> get changeWakeups => _wakeupController.stream;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static String _deriveSupabaseUrl(String functionsBaseUrl) {
    final normalized = _normalizeBaseUrl(functionsBaseUrl);
    const suffix = '/functions/v1';
    if (normalized.endsWith(suffix)) {
      return normalized.substring(0, normalized.length - suffix.length);
    }
    return normalized;
  }

  Map<String, String> _headers(String syncJwt) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $syncJwt',
    };
    final apiKey = _publishableKey.trim();
    if (apiKey.isNotEmpty) {
      headers['apikey'] = apiKey;
    }
    return headers;
  }

  /// POST local ops to `push-sync-ops`.
  Future<PushOpsResult> pushOps({
    required String syncJwt,
    required String deviceId,
    required List<SyncOperation> ops,
  }) async {
    if (ops.isEmpty) {
      return PushOpsResult.empty;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/push-sync-ops',
        data: <String, dynamic>{
          'device_id': deviceId,
          'ops': ops
              .map(
                (op) => <String, dynamic>{
                  'id': op.id,
                  'entity_type': op.entityType,
                  'entity_id': op.entityId,
                  'action': op.action,
                  if (op.fieldDeltas != null)
                    'field_deltas': _parseFieldDeltasJson(op.fieldDeltas!),
                  'local_timestamp': op.localTimestamp.toUtc().toIso8601String(),
                },
              )
              .toList(growable: false),
        },
        options: Options(headers: _headers(syncJwt)),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty push response');
      }

      final results = data['results'];
      if (results is! List) {
        throw const ServerException('Invalid push response');
      }

      final failed = data['failed'];

      return PushOpsResult(
        acks: results
            .whereType<Map<String, dynamic>>()
            .map(_mapPushAck)
            .toList(growable: false),
        rejections: failed is List
            ? failed
                .whereType<Map<String, dynamic>>()
                .map(_mapPushRejection)
                .whereType<PushOpRejection>()
                .toList(growable: false)
            : const [],
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = _extractErrorCode(e);
      if (code == EdgeErrorCodes.deviceCapExceeded ||
          code == EdgeErrorCodes.syncEventCapExceeded) {
        throw SyncCapExceededException(code: code!);
      }
      throw ServerException(
        'Push sync failed: ${e.message}',
        statusCode: status,
        errorCode: code,
      );
    }
  }

  /// Server page size for [pullOps].
  static const int defaultPullLimit = 200;

  /// GET one page of remote ops from `pull-sync-ops`.
  Future<PullOpsPage> pullOps({
    required String syncJwt,
    required int sinceOpSeq,
    int limit = defaultPullLimit,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_functionsBaseUrl/pull-sync-ops',
        queryParameters: <String, dynamic>{
          'since_op_seq': sinceOpSeq,
          'limit': limit,
        },
        options: Options(headers: _headers(syncJwt)),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty pull response');
      }

      final opsJson = data['ops'];
      if (opsJson is! List) {
        throw const ServerException('Invalid pull response');
      }

      final ops = opsJson
          .whereType<Map<String, dynamic>>()
          .map(_mapPullOp)
          .toList(growable: false);

      // The server withholds ops the workspace must not replay, so a page
      // can come back empty or short while more ops sit behind it. Only
      // `has_more` and `next_since_op_seq` describe the real cursor; the
      // page contents do not.
      final nextRaw = data['next_since_op_seq'];
      final nextSinceOpSeq = nextRaw is num
          ? nextRaw.toInt()
          : ops.fold<int>(sinceOpSeq, (max, op) => op.opSeq > max ? op.opSeq : max);

      final hasMoreRaw = data['has_more'];
      final hasMore =
          hasMoreRaw is bool ? hasMoreRaw : ops.length >= limit;

      return PullOpsPage(
        ops: ops,
        nextSinceOpSeq: nextSinceOpSeq,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw ServerException(
        'Pull sync failed: ${e.message}',
        statusCode: status,
        errorCode: _extractErrorCode(e),
      );
    }
  }

  /// Subscribes to ledger/contact/transaction changes for wake-ups.
  Future<void> startMerchantRealtime({
    required String syncJwt,
    required String workspaceId,
  }) {
    return _serialize(
      () => _startMerchantRealtime(
        syncJwt: syncJwt,
        workspaceId: workspaceId,
      ),
    );
  }

  /// Queues channel lifecycle work so overlapping sync cycles cannot each
  /// build a [SupabaseClient] and leak all but the last one.
  Future<void> _serialize(Future<void> Function() action) {
    final previous =
        _channelSetup?.then<void>((_) {}, onError: (Object _) {}) ??
            Future<void>.value();
    final next = previous.then((_) => action());
    _channelSetup = next;
    return next;
  }

  Future<void> _startMerchantRealtime({
    required String syncJwt,
    required String workspaceId,
  }) async {
    if (_subscribedWorkspaceId == workspaceId &&
        _realtimeClient != null &&
        _channel != null) {
      await _realtimeClient!.realtime.setAuth(syncJwt);
      return;
    }

    await _teardownChannel();

    _realtimeClient = SupabaseClient(
      _supabaseUrl,
      _publishableKey,
      headers: {'Authorization': 'Bearer $syncJwt'},
    );
    await _realtimeClient!.realtime.setAuth(syncJwt);

    _subscribedWorkspaceId = workspaceId;
    _channel = _realtimeClient!
        .channel('sync-wakeup-$workspaceId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ledgers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: workspaceId,
          ),
          callback: (_) => _emitWakeup(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contacts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: workspaceId,
          ),
          callback: (_) => _emitWakeup(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: workspaceId,
          ),
          callback: (_) => _emitWakeup(),
        )
        ..subscribe();
  }

  /// Tears down Realtime subscriptions but keeps the wake-up stream alive.
  Future<void> stopRealtime() {
    return _serialize(_teardownChannel);
  }

  /// Closes Realtime and the wake-up stream (provider dispose).
  Future<void> dispose() async {
    await stopRealtime();
    if (!_wakeupController.isClosed) {
      await _wakeupController.close();
    }
  }

  Future<void> _teardownChannel() async {
    final channel = _channel;
    final client = _realtimeClient;
    _channel = null;
    _realtimeClient = null;
    _subscribedWorkspaceId = null;
    if (client == null) {
      return;
    }
    if (channel != null) {
      await client.removeChannel(channel);
    }
    // Disposing the channel alone leaves the socket and its reconnect timer
    // running for the lifetime of the process.
    await client.dispose();
  }

  void _emitWakeup() {
    if (!_wakeupController.isClosed) {
      _wakeupController.add(null);
    }
  }

  PushOpAck _mapPushAck(Map<String, dynamic> row) {
    final serverUpdatedAt = _requireDateTime(row['server_updated_at'], 'ack');
    return PushOpAck(
      auditLogId: _requireString(row['id'], 'ack.id'),
      opSeq: _requireInt(row['op_seq'], 'ack.op_seq'),
      serverUpdatedAt: serverUpdatedAt,
    );
  }

  /// Maps one `failed[]` entry, or null when it cannot identify an op.
  ///
  /// A rejection without a usable id names nothing this device can settle,
  /// so it is dropped rather than failing the whole batch and discarding
  /// the acks parsed alongside it.
  PushOpRejection? _mapPushRejection(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      return null;
    }
    final code = row['code'];
    return PushOpRejection(
      auditLogId: id,
      code: code is String && code.isNotEmpty ? code : 'invalid_request',
    );
  }

  SyncOperation _mapPullOp(Map<String, dynamic> row) {
    final payload = row['payload'];
    String? fieldDeltas;
    if (payload != null) {
      fieldDeltas = payload is String ? payload : jsonEncode(payload);
    }

    // Fail closed: an unknown role must never be credited with more merge
    // authority than the lowest tier.
    final workspaceRole = row['workspace_role'];
    final role = workspaceRole is String && workspaceRole.isNotEmpty
        ? workspaceRole
        : 'viewer';

    return SyncOperation(
      id: _requireString(row['id'], 'op.id'),
      entityType: _requireString(row['entity_type'], 'op.entity_type'),
      entityId: _requireString(row['entity_id'], 'op.entity_id'),
      action: _requireString(row['action'], 'op.action'),
      deviceId: _requireString(row['device_id'], 'op.device_id'),
      role: role,
      localTimestamp: _requireDateTime(row['logged_at'], 'op.logged_at'),
      serverUpdatedAt: _requireDateTime(
        row['server_updated_at'],
        'op.server_updated_at',
      ),
      opSeq: _requireInt(row['op_seq'], 'op.op_seq'),
      fieldDeltas: fieldDeltas,
    );
  }

  // A malformed row must surface as a typed transport error, not an
  // uncaught cast that escapes every `on ServerException` handler upstream.
  // The 422 status marks it non-retryable — retrying cannot repair a payload.

  String _requireString(Object? raw, String field) {
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    throw _malformed(field);
  }

  int _requireInt(Object? raw, String field) {
    if (raw is num) {
      return raw.toInt();
    }
    throw _malformed(field);
  }

  DateTime _requireDateTime(Object? raw, String field) {
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null) {
      throw _malformed(field);
    }
    return parsed.toUtc();
  }

  ServerException _malformed(String field) {
    return ServerException(
      'Malformed sync payload: missing or invalid $field',
      statusCode: 422,
      errorCode: 'sync_payload_malformed',
    );
  }

  dynamic _parseFieldDeltasJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  /// Reads the stable `code` from an error body, falling back to the status.
  ///
  /// Callers branch on this and never on `error`, which is English prose.
  String? _extractErrorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    return edgeCodeForStatus(e.response?.statusCode);
  }
}

/// Outcome of one `push-sync-ops` call.
///
/// The server settles every submitted op exactly once: accepted ops appear
/// in [acks], refused ops in [rejections]. An op missing from both is still
/// pending and will be pushed again.
class PushOpsResult {
  /// Creates a push result.
  const PushOpsResult({required this.acks, required this.rejections});

  /// No ops submitted, nothing settled.
  static const PushOpsResult empty = PushOpsResult(
    acks: [],
    rejections: [],
  );

  /// Ops the server accepted and sequenced.
  final List<PushOpAck> acks;

  /// Ops the server refused and will never accept in this form.
  final List<PushOpRejection> rejections;
}

/// One page of `pull-sync-ops`, with the server's own cursor.
class PullOpsPage {
  /// Creates a pull page.
  const PullOpsPage({
    required this.ops,
    required this.nextSinceOpSeq,
    required this.hasMore,
  });

  /// Ops in this page, oldest first.
  final List<SyncOperation> ops;

  /// The `since_op_seq` to send for the next page.
  final int nextSinceOpSeq;

  /// Whether more ops remain behind this page.
  final bool hasMore;
}

/// A push op the server permanently refused.
class PushOpRejection {
  /// Creates a rejection record.
  const PushOpRejection({required this.auditLogId, required this.code});

  /// Local audit log id the server refused.
  final String auditLogId;

  /// Stable machine-readable reason (`invalid_action`, `invalid_request`).
  final String code;
}

/// Server acknowledgment for a pushed audit log row.
class PushOpAck {
  /// Creates an ack record.
  const PushOpAck({
    required this.auditLogId,
    required this.opSeq,
    required this.serverUpdatedAt,
  });

  /// Local audit log id.
  final String auditLogId;

  /// Assigned server sequence.
  final int opSeq;

  /// Server ordering timestamp.
  final DateTime serverUpdatedAt;
}
