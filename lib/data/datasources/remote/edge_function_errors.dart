import 'package:daftar/core/errors/edge_error_codes.dart';
import 'package:daftar/core/errors/exceptions.dart';
import 'package:daftar/core/errors/failures.dart';
import 'package:dio/dio.dart';

/// Maps a failed Edge Function [DioException] to [ServerException].
///
/// When the body omits `code` (proxy or gateway responses), the status is
/// used to synthesize one so callers can branch on a single field.
ServerException mapEdgeFunctionDioException(
  DioException error, {
  required String fallbackMessage,
}) {
  final status = error.response?.statusCode;
  final body = error.response?.data;
  var message = fallbackMessage;
  String? errorCode;
  int? retryAfterSeconds;

  if (body is Map) {
    final err = body['error'];
    if (err is String && err.isNotEmpty) {
      message = err;
    }
    final code = body['code'];
    if (code is String && code.isNotEmpty) {
      errorCode = code;
    }
    final retryAfter = body['retry_after'];
    if (retryAfter is num) {
      retryAfterSeconds = retryAfter.round();
    }
  }

  return ServerException(
    message,
    statusCode: status,
    errorCode: errorCode ?? edgeCodeForStatus(status),
    retryAfterSeconds: retryAfterSeconds,
  );
}

/// Best-effort code for a response whose body carried none.
String? edgeCodeForStatus(int? status) {
  return switch (status) {
    401 => EdgeErrorCodes.unauthorized,
    403 => EdgeErrorCodes.forbidden,
    404 => EdgeErrorCodes.notFound,
    405 => EdgeErrorCodes.methodNotAllowed,
    409 => EdgeErrorCodes.conflict,
    429 => EdgeErrorCodes.rateLimited,
    500 => EdgeErrorCodes.internalError,
    503 => EdgeErrorCodes.serviceUnavailable,
    _ => null,
  };
}

/// Maps a settled Edge Function error to the failure the app reasons about.
///
/// Branches on the stable [ServerException.errorCode]. Message text is never
/// matched: it is English engineering prose and changes without notice.
Failure mapEdgeFunctionFailure(
  ServerException error, {
  String fallbackCode = 'edge_function_failed',
}) {
  final code = error.errorCode ?? edgeCodeForStatus(error.statusCode);

  return switch (code) {
    EdgeErrorCodes.forbidden => ForbiddenFailure(error.message),
    EdgeErrorCodes.unauthorized => AuthFailure(
        error.message,
        code: EdgeErrorCodes.unauthorized,
      ),
    EdgeErrorCodes.rateLimited => RateLimitedFailure(
        error.message,
        retryAfterSeconds: error.retryAfterSeconds,
      ),
    EdgeErrorCodes.seatCapExceeded => SeatCapExceededFailure(error.message),
    EdgeErrorCodes.invalidRequest ||
    EdgeErrorCodes.invalidAction =>
      ValidationFailure(error.message, code: code),
    _ => NetworkFailure(error.message, code: code ?? fallbackCode),
  };
}

/// Maps invite-class `429 rate_limited` responses to [RateLimitedFailure].
RateLimitedFailure? mapRateLimitedFailure(ServerException error) {
  if (error.statusCode != 429) {
    return null;
  }
  if (error.errorCode != null &&
      error.errorCode != EdgeErrorCodes.rateLimited) {
    return null;
  }
  return RateLimitedFailure(
    error.message,
    retryAfterSeconds: error.retryAfterSeconds,
  );
}

/// Maps `409 seat_cap_exceeded` to [SeatCapExceededFailure].
SeatCapExceededFailure? mapSeatCapExceededFailure(ServerException error) {
  if (error.statusCode != 409) {
    return null;
  }
  if (error.errorCode != null &&
      error.errorCode != EdgeErrorCodes.seatCapExceeded) {
    return null;
  }
  return SeatCapExceededFailure(error.message);
}
