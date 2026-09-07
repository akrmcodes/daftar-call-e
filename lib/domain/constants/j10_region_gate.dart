import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/value_objects/call_eligibility.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';

/// Device-side J.10 region gate (mirrors `agent/calls/j10.py` `region_gate`).
///
/// Does not check DNC or kill switch — those belong to dual-rail split and
/// the run-batch recipient guard.
abstract final class J10RegionGate {
  /// Evaluates call eligibility for a contact phone.
  static CallEligibility evaluate({
    required PhoneNumber phone,
    required String declaredRegion,
    required String allowlistRegion,
    required Set<String> allowlist,
  }) {
    if (phone.isEmpty) {
      return const CallEmpty();
    }

    final e164 = phone.e164;
    if (e164 == null) {
      return const CallInvalid();
    }

    final declaredIso = declaredRegion.trim().toUpperCase();
    if (declaredIso.isEmpty) {
      return const CallUnavailable();
    }

    if (_regionGateFails(
      e164: e164,
      declaredIso: declaredIso,
      allowlistRegion: allowlistRegion,
    )) {
      return const CallUnavailable();
    }

    if (!allowlist.contains(e164)) {
      return CallNotAllowlisted(e164: e164, region: declaredIso);
    }

    return CallEligible(e164: e164, region: declaredIso);
  }

  /// True when the number passes J.10 region gate (allowlist ignored).
  ///
  /// Used for B-trigger HITL — [CallNotAllowlisted] still counts as supported;
  /// PSTN allowlist is enforced later on dispatch.
  static bool isSupportedCallingNumber({
    required PhoneNumber phone,
    required String declaredRegion,
    required String allowlistRegion,
  }) {
    final gate = evaluate(
      phone: phone,
      declaredRegion: declaredRegion,
      allowlistRegion: allowlistRegion,
      allowlist: const {},
    );
    return gate is CallEligible || gate is CallNotAllowlisted;
  }

  /// B-trigger / agent-queue gate: J.10 region supported, not DNC.
  static bool isSupportedContactPhone({
    required String? phoneRaw,
    required String allowlistRegion,
    bool doNotCall = false,
  }) {
    if (doNotCall) {
      return false;
    }
    final phone = PhoneNumber(phoneRaw ?? '');
    final declaredRegion = J10CalleRegions.declaredRegionFor(
      phone.e164,
      allowlistRegion,
    );
    return isSupportedCallingNumber(
      phone: phone,
      declaredRegion: declaredRegion,
      allowlistRegion: allowlistRegion,
    );
  }

  static bool _regionGateFails({
    required String e164,
    required String declaredIso,
    required String allowlistRegion,
  }) {
    if (declaredIso == 'YE' ||
        J10CalleRegions.callingRegion(e164) == 'YE') {
      return true;
    }

    final mapped = J10CalleRegions.callingRegion(e164);
    if (mapped == null) {
      return true;
    }

    if (mapped == J10CalleRegions.nanp) {
      final want = allowlistRegion.trim().toUpperCase();
      return declaredIso != want ||
          !J10CalleRegions.supportedRegions.contains(declaredIso);
    }

    return declaredIso != mapped ||
        !J10CalleRegions.supportedRegions.contains(declaredIso);
  }
}
