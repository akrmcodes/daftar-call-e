import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/constants/j10_region_gate.dart';
import 'package:daftar/domain/value_objects/call_eligibility.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // RFC 555 fictional NANP (agent tests use the same fixture).
  const usPhone = '+15555550100';
  const saPhone = '+966501234567';
  const aePhone = '+971501234567';
  const egPhone = '+201012345678';
  const omPhone = '+96891234567';

  group('J10CalleRegions', () {
    test('supportedRegions includes demo ISO codes and excludes YE', () {
      expect(J10CalleRegions.supportedRegions, containsAll(['US', 'AE', 'SA', 'EG', 'OM']));
      expect(J10CalleRegions.supportedRegions, isNot(contains('YE')));
    });

    test('callingRegion maps prefixes and NANP', () {
      expect(J10CalleRegions.callingRegion(saPhone), 'SA');
      expect(J10CalleRegions.callingRegion('+967771234567'), 'YE');
      expect(J10CalleRegions.callingRegion(usPhone), J10CalleRegions.nanp);
      expect(J10CalleRegions.callingRegion('+999000000000'), isNull);
    });
  });

  group('J10RegionGate.evaluate', () {
    CallEligibility evaluate({
      required PhoneNumber phone,
      required String declaredRegion,
      String allowlistRegion = 'US',
      Set<String>? allowlist,
    }) {
      return J10RegionGate.evaluate(
        phone: phone,
        declaredRegion: declaredRegion,
        allowlistRegion: allowlistRegion,
        allowlist: allowlist ?? const {},
      );
    }

    test('YE local number is callUnavailable even when allowlisted', () {
      const ye = PhoneNumber('0771234567');
      final result = evaluate(
        phone: ye,
        declaredRegion: 'YE',
        allowlist: {ye.e164!},
      );

      expect(result, isA<CallUnavailable>());
    });

    test('SA eligible with declaredRegion SA and on allowlist', () {
      const phone = PhoneNumber('+966 50 123 4567');
      final result = evaluate(
        phone: phone,
        declaredRegion: 'SA',
        allowlist: {saPhone},
      );

      expect(result, isA<CallEligible>());
      final eligible = result as CallEligible;
      expect(eligible.e164, saPhone);
      expect(eligible.region, 'SA');
    });

    test('SA with declaredRegion US is callUnavailable', () {
      const phone = PhoneNumber('+966 50 123 4567');
      final result = evaluate(
        phone: phone,
        declaredRegion: 'US',
        allowlist: {saPhone},
      );

      expect(result, isA<CallUnavailable>());
    });

    test('US NANP eligible with explicit region US from allowlist config', () {
      const phone = PhoneNumber(usPhone);
      final result = evaluate(
        phone: phone,
        declaredRegion: 'US',
        allowlist: {usPhone},
      );

      expect(result, isA<CallEligible>());
      final eligible = result as CallEligible;
      expect(eligible.e164, usPhone);
      expect(eligible.region, 'US');
    });

    test('NANP with declaredRegion CA and allowlistRegion US is unavailable', () {
      const phone = PhoneNumber(usPhone);
      final result = evaluate(
        phone: phone,
        declaredRegion: 'CA',
        allowlist: {usPhone},
      );

      expect(result, isA<CallUnavailable>());
    });

    test('AE EG OM eligible only when on allowlist', () {
      for (final entry in [
        (const PhoneNumber(aePhone), 'AE', aePhone),
        (const PhoneNumber(egPhone), 'EG', egPhone),
        (const PhoneNumber(omPhone), 'OM', omPhone),
      ]) {
        final (phone, region, e164) = entry;

        expect(
          evaluate(phone: phone, declaredRegion: region, allowlist: {e164}),
          isA<CallEligible>(),
        );
        expect(
          evaluate(phone: phone, declaredRegion: region),
          isA<CallNotAllowlisted>(),
        );
      }
    });

    test('empty input is CallEmpty', () {
      expect(
        evaluate(phone: const PhoneNumber(''), declaredRegion: 'US'),
        isA<CallEmpty>(),
      );
      expect(
        evaluate(phone: const PhoneNumber('   '), declaredRegion: 'US'),
        isA<CallEmpty>(),
      );
    });

    test('garbage and too-short input is CallInvalid', () {
      expect(
        evaluate(phone: const PhoneNumber('not-a-phone'), declaredRegion: 'US'),
        isA<CallInvalid>(),
      );
      expect(
        evaluate(phone: const PhoneNumber('77'), declaredRegion: 'US'),
        isA<CallInvalid>(),
      );
    });

    test('valid SA and US not on allowlist are CallNotAllowlisted', () {
      final sa = evaluate(
        phone: const PhoneNumber('+966 50 123 4567'),
        declaredRegion: 'SA',
      );
      expect(sa, isA<CallNotAllowlisted>());
      expect((sa as CallNotAllowlisted).e164, saPhone);
      expect(sa.region, 'SA');

      final us = evaluate(
        phone: const PhoneNumber(usPhone),
        declaredRegion: 'US',
      );
      expect(us, isA<CallNotAllowlisted>());
      expect((us as CallNotAllowlisted).e164, usPhone);
      expect(us.region, 'US');
    });
  });

  group('J10RegionGate.isSupportedCallingNumber', () {
    bool supported({
      required PhoneNumber phone,
      required String declaredRegion,
      String allowlistRegion = 'US',
    }) {
      return J10RegionGate.isSupportedCallingNumber(
        phone: phone,
        declaredRegion: declaredRegion,
        allowlistRegion: allowlistRegion,
      );
    }

    test('YE is unsupported even when allowlisted on evaluate', () {
      const ye = PhoneNumber('0771234567');
      expect(
        supported(phone: ye, declaredRegion: 'YE'),
        isFalse,
      );
    });

    test('empty and invalid phones are unsupported', () {
      expect(supported(phone: const PhoneNumber(''), declaredRegion: 'US'), isFalse);
      expect(
        supported(phone: const PhoneNumber('not-a-phone'), declaredRegion: 'US'),
        isFalse,
      );
    });

    test('US and SA are supported with empty allowlist', () {
      expect(
        supported(phone: const PhoneNumber(usPhone), declaredRegion: 'US'),
        isTrue,
      );
      expect(
        supported(
          phone: const PhoneNumber('+966 50 123 4567'),
          declaredRegion: 'SA',
        ),
        isTrue,
      );
    });

    test('isSupportedContactPhone respects doNotCall', () {
      expect(
        J10RegionGate.isSupportedContactPhone(
          phoneRaw: usPhone,
          allowlistRegion: 'US',
          doNotCall: true,
        ),
        isFalse,
      );
      expect(
        J10RegionGate.isSupportedContactPhone(
          phoneRaw: usPhone,
          allowlistRegion: 'US',
        ),
        isTrue,
      );
    });
  });
}
