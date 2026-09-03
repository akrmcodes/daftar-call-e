import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:daftar/domain/constants/run_batch_recipient_guard.dart';
import 'package:daftar/domain/enums/outreach_rail.dart';
import 'package:daftar/domain/enums/reminder_tone_band.dart';
import 'package:daftar/domain/value_objects/collections_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usPhone = '+15555550100';

  CollectionsCandidate candidate({
    required String id,
    String? phone,
    OutreachRail rail = OutreachRail.both,
    bool doNotCall = false,
  }) {
    return CollectionsCandidate(
      contactId: id,
      name: id,
      phone: phone,
      email: 'test@example.com',
      ledgerId: 'ledger',
      netBalance: -500,
      currencyCode: 'USD',
      ageDays: 30,
      toneBand: ReminderToneBand.firm,
      doNotCall: doNotCall,
      rail: rail,
    );
  }

  CalleDevicePolicy policy({
    bool allowDial = true,
    Set<String>? allowlist,
  }) {
    return CalleDevicePolicy(
      allowDial: allowDial,
      allowlist: allowlist ?? {usPhone},
      allowlistRegion: 'US',
    );
  }

  test('allowlisted US on call rail is included', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(id: 'us', phone: usPhone),
      ],
      policy: policy(),
    );

    expect(result.recipients, hasLength(1));
    expect(result.recipients.single.phoneE164, usPhone);
    expect(result.recipients.single.region, 'US');
    expect(result.omitted, isEmpty);
  });

  test('not on allowlist is omitted with notAllowlisted', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(id: 'us', phone: usPhone),
      ],
      policy: policy(allowlist: {}),
    );

    expect(result.recipients, isEmpty);
    expect(result.omitted.single.reason, RunBatchOmitReason.notAllowlisted);
  });

  test('doNotCall is omitted with dnc', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(id: 'us', phone: usPhone, doNotCall: true),
      ],
      policy: policy(),
    );

    expect(result.recipients, isEmpty);
    expect(result.omitted.single.reason, RunBatchOmitReason.dnc);
  });

  test('kill switch off omits with killSwitch even when allowlisted', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(id: 'us', phone: usPhone),
      ],
      policy: policy(allowDial: false),
    );

    expect(result.recipients, isEmpty);
    expect(result.omitted.single.reason, RunBatchOmitReason.killSwitch);
  });

  test('YE phone is omitted as unsupportedRegion', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(
          id: 'ye',
          phone: '0771234567',
          rail: OutreachRail.both,
        ),
      ],
      policy: policy(allowlist: {'+967771234567'}),
    );

    expect(result.recipients, isEmpty);
    expect(result.omitted.single.reason, RunBatchOmitReason.unsupportedRegion);
  });

  test('email-only rail is notCallRail', () {
    final result = RunBatchRecipientGuard.select(
      candidates: [
        candidate(
          id: 'email',
          phone: usPhone,
          rail: OutreachRail.email,
        ),
      ],
      policy: policy(),
    );

    expect(result.recipients, isEmpty);
    expect(result.omitted.single.reason, RunBatchOmitReason.notCallRail);
  });

  test('caps recipients at five', () {
    final candidates = List.generate(
      6,
      (index) => candidate(
        id: 'c$index',
        phone: usPhone,
      ),
    );

    final result = RunBatchRecipientGuard.select(
      candidates: candidates,
      policy: policy(),
    );

    expect(result.recipients, hasLength(5));
    expect(
      result.omitted.where((row) => row.reason == RunBatchOmitReason.overCap),
      hasLength(1),
    );
  });
}
