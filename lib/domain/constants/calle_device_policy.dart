import 'package:daftar/domain/value_objects/phone_number.dart';

/// Compile-time CALL-E device policy (kill switch + allowlist + NANP region).
///
/// Parse rules mirror [`agent/calls/settings.py`](../../../agent/calls/settings.py)
/// except allowlist entries are normalized to E.164 via [PhoneNumber] so spaced
/// or dashed owner input still matches stored phones. Never log E.164.
class CalleDevicePolicy {
  /// Creates a device policy.
  const CalleDevicePolicy({
    required this.allowDial,
    required this.allowlist,
    required this.allowlistRegion,
  });

  /// Parses raw env-style strings (lockstep with Cloud Run).
  factory CalleDevicePolicy.parse({
    required String allowDialRaw,
    required String allowlistRaw,
    required String allowlistRegionRaw,
  }) {
    final region = allowlistRegionRaw.trim();
    return CalleDevicePolicy(
      allowDial: allowDialRaw == 'true',
      allowlist: _parseAllowlist(allowlistRaw),
      allowlistRegion: region.isEmpty ? 'US' : region.toUpperCase(),
    );
  }

  /// Policy from compile-time dart-defines (empty defaults).
  factory CalleDevicePolicy.fromCompiled() {
    return CalleDevicePolicy.parse(
      allowDialRaw: _compiledAllowDial,
      allowlistRaw: _compiledAllowlist,
      allowlistRegionRaw: _compiledAllowlistRegion,
    );
  }

  /// Dart-define key for the PSTN kill switch.
  static const String allowDialKey = 'CALLE_ALLOW_DIAL';

  /// Dart-define key for comma-separated allowlisted E.164 values.
  static const String allowlistKey = 'CALLE_ALLOWLIST';

  /// Dart-define key for NANP declared region (demo `US`).
  static const String allowlistRegionKey = 'CALLE_ALLOWLIST_REGION';

  static const String _compiledAllowDial = String.fromEnvironment(allowDialKey);
  static const String _compiledAllowlist = String.fromEnvironment(allowlistKey);
  static const String _compiledAllowlistRegion = String.fromEnvironment(
    allowlistRegionKey,
  );

  /// PSTN allowed only when the raw value is the exact lowercase string `true`.
  final bool allowDial;

  /// Exact-match E.164 allowlist. Empty means nobody.
  final Set<String> allowlist;

  /// Declared ISO for NANP numbers — never inferred from `+1`.
  final String allowlistRegion;

  static Set<String> _parseAllowlist(String raw) {
    final entries = <String>{};
    for (final part in raw.split(',')) {
      final item = part.trim();
      if (item.isEmpty) {
        continue;
      }
      final e164 = PhoneNumber(item).e164;
      if (e164 != null) {
        entries.add(e164);
      }
    }
    return entries;
  }
}
