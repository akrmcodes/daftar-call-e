/// Stable machine-readable error codes returned by every Edge Function.
///
/// The body carries `{ "error": <English diagnostic>, "code": <this> }`.
/// Only the code is a contract — the message is engineering prose that must
/// never reach a merchant or drive a branch.
abstract final class EdgeErrorCodes {
  /// Missing or invalid credential — re-authentication may help.
  static const String unauthorized = 'unauthorized';

  /// Valid credential, insufficient role. Never retry, never re-exchange.
  static const String forbidden = 'forbidden';

  /// Malformed request body or parameters.
  static const String invalidRequest = 'invalid_request';

  /// Op action verb outside the server's allow-list.
  static const String invalidAction = 'invalid_action';

  /// Target row does not exist.
  static const String notFound = 'not_found';

  /// Wrong HTTP verb for the endpoint.
  static const String methodNotAllowed = 'method_not_allowed';

  /// State conflict (duplicate invite, stale row).
  static const String conflict = 'conflict';

  /// Workspace worker seats are full.
  static const String seatCapExceeded = 'seat_cap_exceeded';

  /// Device registration cap reached for this workspace.
  static const String deviceCapExceeded = 'device_cap_exceeded';

  /// Monthly sync event cap reached for this workspace.
  static const String syncEventCapExceeded = 'sync_event_cap_exceeded';

  /// The server could not register this device.
  static const String deviceRegistrationFailed = 'device_registration_failed';

  /// The server could not persist usage counters.
  static const String usageCounterWriteFailed = 'usage_counter_write_failed';

  /// Too many requests in a short window.
  static const String rateLimited = 'rate_limited';

  /// Unhandled server-side error.
  static const String internalError = 'internal_error';

  /// Dependency unavailable; retrying later may succeed.
  static const String serviceUnavailable = 'service_unavailable';

  /// Every code the server can emit.
  static const List<String> all = [
    unauthorized,
    forbidden,
    invalidRequest,
    invalidAction,
    notFound,
    methodNotAllowed,
    conflict,
    seatCapExceeded,
    deviceCapExceeded,
    syncEventCapExceeded,
    deviceRegistrationFailed,
    usageCounterWriteFailed,
    rateLimited,
    internalError,
    serviceUnavailable,
  ];
}
