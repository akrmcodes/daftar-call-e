import 'package:daftar/core/env/env.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:dio/dio.dart';

/// Remote activation via Supabase Edge Function (pure HTTP, no Supabase SDK).
class ActivationApiDs {
  ActivationApiDs({
    required Dio dio,
    String? baseUrl,
  }) : _dio = dio,
       _baseUrl = _normalizeBaseUrl(baseUrl ?? Env.activationApiBaseUrl);

  final Dio _dio;
  final String _baseUrl;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  /// POST `/activate` — returns the signed entitlement token string.
  Future<String> activate({required String code}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/activate',
        data: <String, String>{'code': code.trim()},
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const ServerException('Empty activation response.');
      }

      final token = data['token'] as String? ?? data['payload'] as String?;
      if (token == null || token.isEmpty) {
        throw const ServerException(
          'Activation response missing signed token.',
        );
      }
      return token;
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Activation request failed.',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
