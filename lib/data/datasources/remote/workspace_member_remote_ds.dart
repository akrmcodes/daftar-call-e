import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/data/models/workspace_member_model.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:dio/dio.dart';

/// Remote data source for workspace member collaboration (Stage 8.5).
class WorkspaceMemberRemoteDs {
  WorkspaceMemberRemoteDs({
    required Dio dio,
    required SyncTokenStore syncTokenStore,
    String? functionsBaseUrl,
    String? publishableKey,
  })  : _dio = dio,
        _syncTokenStore = syncTokenStore,
        _functionsBaseUrl = _normalizeBaseUrl(
          functionsBaseUrl ?? Env.activationApiBaseUrl,
        ),
        _restBaseUrl = _deriveRestBaseUrl(
          functionsBaseUrl ?? Env.activationApiBaseUrl,
        ),
        _publishableKey = publishableKey ?? Env.supabasePublishableKey;

  final Dio _dio;
  final SyncTokenStore _syncTokenStore;
  final String _functionsBaseUrl;
  final String _restBaseUrl;
  final String _publishableKey;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  static String _deriveRestBaseUrl(String functionsBaseUrl) {
    final normalized = _normalizeBaseUrl(functionsBaseUrl);
    if (normalized.endsWith('/functions/v1')) {
      return normalized.replaceFirst('/functions/v1', '/rest/v1');
    }
    return normalized.replaceFirst(RegExp(r'/functions/v1$'), '/rest/v1');
  }

  Future<Map<String, String>> _authHeaders() async {
    final bundle = await _syncTokenStore.read();
    if (bundle == null || bundle.isExpired) {
      throw const AuthException('Sync session expired. Sign in again.');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${bundle.syncToken}',
    };
    final apiKey = _publishableKey.trim();
    if (apiKey.isNotEmpty) {
      headers['apikey'] = apiKey;
    }
    return headers;
  }

  Future<String> _workspaceId() async {
    final bundle = await _syncTokenStore.read();
    if (bundle == null) {
      throw const AuthException('No sync session.');
    }
    return bundle.workspaceId;
  }

  Future<List<WorkspaceMemberModel>> listMembers() async {
    final workspaceId = await _workspaceId();
    final headers = await _authHeaders();

    try {
      final response = await _dio.get<List<dynamic>>(
        '$_restBaseUrl/workspace_members',
        queryParameters: <String, String>{
          'workspace_id': 'eq.$workspaceId',
          'select': '*',
          'order': 'seat_index.asc',
        },
        options: Options(headers: headers),
      );

      final rows = response.data ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(WorkspaceMemberModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Failed to list workspace members.',
      );
    }
  }

  Future<WorkerInviteResponse> inviteWorker({
    required String inviteeEmail,
    required WorkspaceRole role,
  }) async {
    final headers = await _authHeaders();
    final roleStr = role == WorkspaceRole.editor ? 'editor' : 'viewer';

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/invite-worker',
        data: <String, String>{
          'invitee_email': inviteeEmail,
          'role': roleStr,
        },
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty invite response.');
      }

      return WorkerInviteResponse.fromJson(data);
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Invite request failed.',
      );
    }
  }

  Future<void> revokeInvite({required String memberId}) async {
    final headers = await _authHeaders();

    try {
      await _dio.post<void>(
        '$_functionsBaseUrl/revoke-worker-invite',
        data: <String, String>{'member_id': memberId},
        options: Options(headers: headers),
      );
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Failed to revoke invite.',
      );
    }
  }

  Future<void> removeMember({required String memberId}) async {
    final headers = await _authHeaders();

    try {
      await _dio.delete<void>(
        '$_restBaseUrl/workspace_members',
        queryParameters: <String, String>{'id': 'eq.$memberId'},
        options: Options(headers: headers),
      );
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Failed to remove member.',
      );
    }
  }

  Future<List<InviteRenewalRequestModel>> listRenewalRequests() async {
    final headers = await _authHeaders();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_functionsBaseUrl/list-invite-renewal-requests',
        options: Options(headers: headers),
      );
      final data = response.data;
      if (data == null) {
        return const [];
      }
      final rows = data['requests'];
      if (rows is! List) {
        return const [];
      }
      return rows
          .whereType<Map<String, dynamic>>()
          .map(InviteRenewalRequestModel.fromJson)
          .toList(growable: false);
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Failed to list renewal requests.',
      );
    }
  }

  Future<void> fulfillRenewalRequest({required String renewalId}) async {
    final headers = await _authHeaders();

    try {
      await _dio.post<void>(
        '$_functionsBaseUrl/fulfill-invite-renewal-request',
        data: <String, String>{'renewal_id': renewalId},
        options: Options(headers: headers),
      );
    } on DioException catch (error) {
      throw mapEdgeFunctionDioException(
        error,
        fallbackMessage: 'Failed to fulfill renewal request.',
      );
    }
  }
}

/// Parsed invite-worker Edge Function response.
class WorkerInviteResponse {
  const WorkerInviteResponse({
    required this.memberId,
    required this.inviteUrl,
    required this.role,
    required this.expiresAt,
    required this.requestedRole,
    required this.roleDowngraded,
  });

  factory WorkerInviteResponse.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'viewer';
    final role = WorkspaceRole.fromString(roleStr) ?? WorkspaceRole.viewer;
    final requestedRaw = json['requested_role'];
    final requestedRole = requestedRaw is String
        ? WorkspaceRole.fromString(requestedRaw) ?? role
        : role;
    final expiresRaw = json['expires_at'] as String?;
    final downgraded = json['role_downgraded'];
    return WorkerInviteResponse(
      memberId: json['member_id'] as String,
      inviteUrl: json['invite_url'] as String,
      role: role,
      expiresAt: expiresRaw != null
          ? DateTime.parse(expiresRaw).toUtc()
          : DateTime.now().toUtc(),
      requestedRole: requestedRole,
      // The server states the downgrade; comparing roles would also fire
      // when the caller simply asked for viewer and got viewer.
      roleDowngraded: downgraded == true,
    );
  }

  final String memberId;
  final String inviteUrl;
  final WorkspaceRole role;
  final DateTime expiresAt;

  /// Role the owner asked for, echoed by the server.
  final WorkspaceRole requestedRole;

  /// Whether the server granted less than [requestedRole].
  final bool roleDowngraded;
}

/// Parsed invite renewal request row from Edge Function.
class InviteRenewalRequestModel {
  const InviteRenewalRequestModel({
    required this.id,
    required this.workspaceId,
    required this.originalToken,
    required this.invitedEmail,
    required this.createdAt,
  });

  factory InviteRenewalRequestModel.fromJson(Map<String, dynamic> json) {
    final payload = json['intent_payload'];
    var invitedEmail = '';
    if (payload is Map) {
      final raw = payload['invited_email'];
      if (raw is String) {
        invitedEmail = raw;
      }
    }
    final createdRaw = json['created_at'] as String?;
    return InviteRenewalRequestModel(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      originalToken: json['original_token'] as String,
      invitedEmail: invitedEmail,
      createdAt: createdRaw != null
          ? DateTime.parse(createdRaw).toUtc()
          : DateTime.now().toUtc(),
    );
  }

  final String id;
  final String workspaceId;
  final String originalToken;
  final String invitedEmail;
  final DateTime createdAt;
}
