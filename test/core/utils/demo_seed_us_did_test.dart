import 'dart:io';

import 'package:daftar/core/utils/demo_seed_us_did.dart';
import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const usFixture = '+15555550100';

  group('DemoSeedUsDid', () {
    test('yemenPlaceholder uses valid 77-prefix E.164 for indices 0-6', () {
      for (var i = 0; i < 7; i++) {
        final phone = PhoneNumber(DemoSeedUsDid.yemenPlaceholder(i));
        expect(phone.isValid, isTrue, reason: 'index $i');
        expect(phone.e164, '+96777123456$i', reason: 'index $i');
        expect(J10CalleRegions.callingRegion(phone.e164!), 'YE', reason: 'index $i');
      }
    });

    test('resolve accepts valid NANP override', () {
      expect(DemoSeedUsDid.resolve(override: usFixture), usFixture);
      expect(
        J10CalleRegions.callingRegion(usFixture),
        J10CalleRegions.nanp,
      );
    });

    test('resolve rejects empty, YE, SA, and garbage', () {
      expect(DemoSeedUsDid.resolve(override: ''), isNull);
      expect(DemoSeedUsDid.resolve(override: '0771234567'), isNull);
      expect(DemoSeedUsDid.resolve(override: '+966501234567'), isNull);
      expect(DemoSeedUsDid.resolve(override: 'not-a-phone'), isNull);
    });

    test('committed lib and tool docs contain no live +1 E.164', () {
      final paths = [
        'lib/core/utils/demo_store_seeder.dart',
        'lib/core/utils/demo_seed_us_did.dart',
        'tool/demo_seed_emails.example.json',
        'tool/demo_seed_emails.md',
      ];
      final pattern = RegExp(r'\+1\d{10}');

      for (final path in paths) {
        final text = File(path).readAsStringSync();
        expect(pattern.hasMatch(text), isFalse, reason: path);
      }
    });
  });
}
