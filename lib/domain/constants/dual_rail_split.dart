import 'package:daftar/domain/constants/closing_agent_constants.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/constants/j10_region_gate.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/value_objects/call_eligibility.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:equatable/equatable.dart';

/// Ranked shortlist plus capped call and email sets (Appendix D dual rail).
class DualRailSplitResult extends Equatable {
  /// Creates a split result.
  const DualRailSplitResult({
    required this.ranked,
    required this.callSet,
    required this.emailSet,
  });

  /// Full ranked overdue list with [OutreachRail] attached.
  final List<CollectionsCandidate> ranked;

  /// CALL-E call set (≤ [ClosingAgentConstants.maxCallRecipients]).
  final List<CollectionsCandidate> callSet;

  /// SMTP send set (≤ [ClosingAgentConstants.maxEmailRecipients]).
  final List<CollectionsCandidate> emailSet;

  /// Ranked Top 5 of the email send set for MIME PDFs.
  List<CollectionsCandidate> get pdfTop5 => emailSet
      .take(ClosingAgentConstants.statementSetSize)
      .toList(growable: false);

  @override
  List<Object?> get props => [ranked, callSet, emailSet];
}

/// Device-side dual-rail split after FIFO aging rank.
abstract final class DualRailSplit {
  /// Splits [ranked] into call/email sets and attaches [OutreachRail] per row.
  static DualRailSplitResult split({
    required List<CollectionsCandidate> ranked,
    required String allowlistRegion,
    required Set<String> allowlist,
    required bool allowDial,
  }) {
    final callIds = <String>{};
    final emailIds = <String>{};
    final regionUnavailableById = <String, bool>{};

    for (final candidate in ranked) {
      final emailRaw = ContactEmail.isPresentAndValid(candidate.email);
      final phone = PhoneNumber(candidate.phone ?? '');
      final e164 = phone.e164;
      final declaredRegion = J10CalleRegions.declaredRegionFor(
        e164,
        allowlistRegion,
      );
      final gate = J10RegionGate.evaluate(
        phone: phone,
        declaredRegion: declaredRegion,
        allowlistRegion: allowlistRegion,
        allowlist: allowlist,
      );

      final regionUnavailable = phone.isNotEmpty && gate is CallUnavailable;
      regionUnavailableById[candidate.contactId] = regionUnavailable;

      final callRaw =
          gate is CallEligible && !candidate.doNotCall && allowDial;
      if (callRaw && callIds.length < ClosingAgentConstants.maxCallRecipients) {
        callIds.add(candidate.contactId);
      }
      if (emailRaw &&
          emailIds.length < ClosingAgentConstants.maxEmailRecipients) {
        emailIds.add(candidate.contactId);
      }
    }

    final withRails = <CollectionsCandidate>[];
    for (final candidate in ranked) {
      final inCall = callIds.contains(candidate.contactId);
      final inEmail = emailIds.contains(candidate.contactId);
      final regionUnavailable =
          regionUnavailableById[candidate.contactId] ?? false;

      final OutreachRail rail;
      if (inCall && inEmail) {
        rail = OutreachRail.both;
      } else if (inCall) {
        rail = OutreachRail.call;
      } else if (inEmail && regionUnavailable) {
        rail = OutreachRail.callUnavailable;
      } else if (inEmail) {
        rail = OutreachRail.email;
      } else {
        rail = OutreachRail.skipped;
      }

      withRails.add(
        CollectionsCandidate(
          contactId: candidate.contactId,
          name: candidate.name,
          phone: candidate.phone,
          email: candidate.email,
          ledgerId: candidate.ledgerId,
          netBalance: candidate.netBalance,
          currencyCode: candidate.currencyCode,
          ageDays: candidate.ageDays,
          toneBand: candidate.toneBand,
          daysSinceLastPayment: candidate.daysSinceLastPayment,
          daysSinceLastDebt: candidate.daysSinceLastDebt,
          doNotCall: candidate.doNotCall,
          rail: rail,
        ),
      );
    }

    final callSet = [
      for (final row in withRails)
        if (callIds.contains(row.contactId)) row,
    ];
    final emailSet = [
      for (final row in withRails)
        if (emailIds.contains(row.contactId)) row,
    ];

    return DualRailSplitResult(
      ranked: List<CollectionsCandidate>.unmodifiable(withRails),
      callSet: List<CollectionsCandidate>.unmodifiable(callSet),
      emailSet: List<CollectionsCandidate>.unmodifiable(emailSet),
    );
  }
}
