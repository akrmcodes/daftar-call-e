import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/constants/j10_region_gate.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/value_objects/call_eligibility.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:equatable/equatable.dart';

/// Omission reason for a call-set row (mirrors server `RejectReason` subset).
enum RunBatchOmitReason {
  /// Row is not on the call rail.
  notCallRail,

  /// Invalid or missing E.164.
  invalidPhone,

  /// J.10 region gate failed (including YE).
  unsupportedRegion,

  /// Contact has do-not-call set.
  dnc,

  /// E.164 not on the device allowlist.
  notAllowlisted,

  /// `CALLE_ALLOW_DIAL` is off.
  killSwitch,

  /// Call set exceeded [ClosingAgentConstants.maxCallRecipients].
  overCap,
}

/// One recipient that may be sent to `run-batch`.
class RunBatchRecipient extends Equatable {
  /// Creates a guarded recipient row.
  const RunBatchRecipient({
    required this.contactId,
    required this.phoneE164,
    required this.region,
  });

  /// Drift contact id.
  final String contactId;

  /// Allowlisted E.164 (`+` + digits).
  final String phoneE164;

  /// J.10 ISO region for CALL-E.
  final String region;

  @override
  List<Object?> get props => [contactId, phoneE164, region];
}

/// One call-set row omitted by the guard.
class RunBatchOmittedRecipient extends Equatable {
  /// Creates an omitted row.
  const RunBatchOmittedRecipient({
    required this.contactId,
    required this.reason,
  });

  /// Drift contact id.
  final String contactId;

  /// Why this row must not be dialed.
  final RunBatchOmitReason reason;

  @override
  List<Object?> get props => [contactId, reason];
}

/// Result of the last device gate before `run-batch`.
class RunBatchRecipientGuardResult extends Equatable {
  /// Creates a guard result.
  const RunBatchRecipientGuardResult({
    required this.recipients,
    required this.omitted,
  });

  /// Ordered recipients (≤ [ClosingAgentConstants.maxCallRecipients]).
  final List<RunBatchRecipient> recipients;

  /// Rows dropped with a reason (defense in depth).
  final List<RunBatchOmittedRecipient> omitted;

  @override
  List<Object?> get props => [recipients, omitted];
}

/// Device-side last gate before building a `run-batch` body.
abstract final class RunBatchRecipientGuard {
  /// Selects dialable recipients from [candidates] using [policy].
  ///
  /// Walks [candidates] in order; only rows on the call rail are considered.
  /// Never logs phone numbers.
  static RunBatchRecipientGuardResult select({
    required List<CollectionsCandidate> candidates,
    required CalleDevicePolicy policy,
  }) {
    final recipients = <RunBatchRecipient>[];
    final omitted = <RunBatchOmittedRecipient>[];

    for (final candidate in candidates) {
      final onCallRail =
          candidate.rail == OutreachRail.call ||
          candidate.rail == OutreachRail.both;
      if (!onCallRail) {
        omitted.add(
          RunBatchOmittedRecipient(
            contactId: candidate.contactId,
            reason: RunBatchOmitReason.notCallRail,
          ),
        );
        continue;
      }

      final reason = _rejectReason(candidate: candidate, policy: policy);
      if (reason != null) {
        omitted.add(
          RunBatchOmittedRecipient(
            contactId: candidate.contactId,
            reason: reason,
          ),
        );
        continue;
      }

      if (recipients.length >= ClosingAgentConstants.maxCallRecipients) {
        omitted.add(
          RunBatchOmittedRecipient(
            contactId: candidate.contactId,
            reason: RunBatchOmitReason.overCap,
          ),
        );
        continue;
      }

      final phone = PhoneNumber(candidate.phone ?? '');
      final e164 = phone.e164!;
      final gate = J10RegionGate.evaluate(
        phone: phone,
        declaredRegion: J10CalleRegions.declaredRegionFor(
          e164,
          policy.allowlistRegion,
        ),
        allowlistRegion: policy.allowlistRegion,
        allowlist: policy.allowlist,
      );
      final eligible = gate as CallEligible;

      recipients.add(
        RunBatchRecipient(
          contactId: candidate.contactId,
          phoneE164: eligible.e164,
          region: eligible.region,
        ),
      );
    }

    return RunBatchRecipientGuardResult(
      recipients: List<RunBatchRecipient>.unmodifiable(recipients),
      omitted: List<RunBatchOmittedRecipient>.unmodifiable(omitted),
    );
  }

  static RunBatchOmitReason? _rejectReason({
    required CollectionsCandidate candidate,
    required CalleDevicePolicy policy,
  }) {
    if (candidate.doNotCall) {
      return RunBatchOmitReason.dnc;
    }

    if (!policy.allowDial) {
      return RunBatchOmitReason.killSwitch;
    }

    final phone = PhoneNumber(candidate.phone ?? '');
    final e164 = phone.e164;
    if (e164 == null) {
      return RunBatchOmitReason.invalidPhone;
    }

    final declaredRegion = J10CalleRegions.declaredRegionFor(
      e164,
      policy.allowlistRegion,
    );
    final gate = J10RegionGate.evaluate(
      phone: phone,
      declaredRegion: declaredRegion,
      allowlistRegion: policy.allowlistRegion,
      allowlist: policy.allowlist,
    );

    return switch (gate) {
      CallEligible() => null,
      CallUnavailable() => RunBatchOmitReason.unsupportedRegion,
      CallNotAllowlisted() => RunBatchOmitReason.notAllowlisted,
      CallEmpty() || CallInvalid() => RunBatchOmitReason.invalidPhone,
    };
  }
}
