import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/services/device_identity_store.dart';
import 'package:daftar/core/services/sync_token_store.dart';
import 'package:daftar/data/datasources/remote/edge_function_errors.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claim_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_claimed_by.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_intent.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_resolve_result.dart';
import 'package:daftar/domain/entities/deep_link/deep_link_token_kind.dart';
import 'package:daftar/domain/enums/workspace_role.dart';
import 'package:daftar/domain/repositories/deep_link_repository.dart';
import 'package:dio/dio.dart';

/// Dio client for create / claim / request-new-invite Edge Functions.
class DeepLinkRemoteDs {
  /// Creates the remote data source.
  DeepLinkRemoteDs({
    required Dio dio,
    required SyncTokenStore syncTokenStore,
    String? functionsBaseUrl,
    String? publishableKey,
  })  : _dio = dio,
        _syncTokenStore = syncTokenStore,
        _functionsBaseUrl = _normalizeBaseUrl(
          functionsBaseUrl ?? Env.activationApiBaseUrl,
        ),
        _publishableKey = publishableKey ?? Env.supabasePublishableKey;

  final Dio _dio;
  final SyncTokenStore _syncTokenStore;
  final String _functionsBaseUrl;
  final String _publishableKey;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-device-id': DeviceIdentity.current,
    };
    final apiKey = _publishableKey.trim();
    if (apiKey.isNotEmpty) {
      headers['apikey'] = apiKey;
    }

    final bundle = await _syncTokenStore.read();
    if (bundle != null && bundle.isValid) {
      headers['Authorization'] = 'Bearer ${bundle.syncToken}';
    } else if (requireAuth) {
      throw const AuthException('Sync session required.');
    }
    return headers;
  }

  /// POST `claim-deep-link`.
  Future<DeepLinkClaimResult> claimToken(
    String token, {
    String? googleEmail,
  }) async {
    try {
      final body = <String, String>{'token': token};
      if (googleEmail != null && googleEmail.isNotEmpty) {
        body['google_email'] = googleEmail;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/claim-deep-link',
        data: body,
        options: Options(headers: await _headers()),
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty claim response');
      }
      return mapClaimResponse(data);
    } on DioException catch (e) {
      throw ServerException('Claim failed: ${e.message}');
    }
  }

  /// POST `resolve-deep-link` (read-only preview).
  Future<DeepLinkResolveResult> resolveToken(String token) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/resolve-deep-link',
        data: <String, String>{'token': token},
        options: Options(headers: await _headers()),
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty resolve response');
      }
      return mapResolveResponse(data);
    } on DioException catch (e) {
      throw ServerException('Resolve failed: ${e.message}');
    }
  }

  /// POST `request-new-invite`.
  Future<void> requestNewInvite(String token) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/request-new-invite',
        data: <String, String>{'token': token},
        options: Options(headers: await _headers()),
      );
      final status = response.data?['status'];
      if (status != 'notified') {
        throw const ServerException('Renewal request failed');
      }
    } on DioException catch (e) {
      throw mapEdgeFunctionDioException(
        e,
        fallbackMessage: 'Renewal request failed.',
      );
    }
  }

  /// POST `create-deep-link`.
  Future<CreatedDeepLink> createDeepLink({
    required DeepLinkTokenKind kind,
    required Map<String, Object?> intentPayload,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_functionsBaseUrl/create-deep-link',
        data: <String, dynamic>{
          'kind': kind.toWire(),
          'intent_payload': intentPayload,
        },
        options: Options(headers: await _headers(requireAuth: true)),
      );
      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty create response');
      }
      return CreatedDeepLink(
        token: data['token'] as String,
        url: data['url'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String).toUtc(),
      );
    } on DioException catch (e) {
      throw mapEdgeFunctionDioException(
        e,
        fallbackMessage: 'Create deep link failed.',
      );
    }
  }

  /// Maps Edge JSON to sealed [DeepLinkClaimResult] (never invents statuses).
  static DeepLinkClaimResult mapClaimResponse(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    switch (status) {
      case 'ok':
        return DeepLinkClaimOk(_mapIntent(data));
      case 'expired':
        return const DeepLinkClaimExpired();
      case 'revoked':
        return const DeepLinkClaimRevoked();
      case 'not_found':
        return const DeepLinkClaimNotFound();
      case 'already_claimed':
        final claimedBy = DeepLinkClaimedBy.fromString(
              data['claimed_by'] as String?,
            ) ??
            DeepLinkClaimedBy.byOther;
        return DeepLinkClaimAlreadyClaimed(claimedBy);
      default:
        throw ServerException('Unknown claim status: $status');
    }
  }

  static DeepLinkIntent _mapIntent(Map<String, dynamic> data) {
    final kind = DeepLinkTokenKind.fromString(data['kind'] as String?) ??
        DeepLinkTokenKind.share;
    final intent = data['intent'];
    if (intent is! Map<String, dynamic>) {
      return DeepLinkIntent(kind: kind);
    }

    return DeepLinkIntent(
      kind: kind,
      workspaceId: intent['workspace_id'] as String?,
      memberId: intent['member_id'] as String?,
      contactId: intent['contact_id'] as String?,
      referrerId: intent['referrer_id'] as String?,
      invitedEmail: intent['invited_email'] as String?,
      role: WorkspaceRole.fromString(intent['role'] as String?),
    );
  }

  /// Maps Edge JSON to sealed [DeepLinkResolveResult].
  static DeepLinkResolveResult mapResolveResponse(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    switch (status) {
      case 'active':
        return DeepLinkResolveActive(_mapIntent(data));
      case 'expired':
        return const DeepLinkResolveExpired();
      case 'revoked':
        return const DeepLinkResolveRevoked();
      case 'not_found':
        return const DeepLinkResolveNotFound();
      case 'already_claimed':
        final claimedBy = DeepLinkClaimedBy.fromString(
              data['claimed_by'] as String?,
            ) ??
            DeepLinkClaimedBy.byOther;
        return DeepLinkResolveAlreadyClaimed(claimedBy);
      default:
        throw ServerException('Unknown resolve status: $status');
    }
  }
}
