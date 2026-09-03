import 'package:daftar/domain/constants/calle_device_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CalleDevicePolicy.parse', () {
    test('allowDial is true only for exact lowercase true', () {
      expect(
        CalleDevicePolicy.parse(
          allowDialRaw: 'true',
          allowlistRaw: '',
          allowlistRegionRaw: 'US',
        ).allowDial,
        isTrue,
      );
      for (final raw in ['TRUE', '1', 'yes', '', 'false']) {
        expect(
          CalleDevicePolicy.parse(
            allowDialRaw: raw,
            allowlistRaw: '',
            allowlistRegionRaw: 'US',
          ).allowDial,
          isFalse,
          reason: raw,
        );
      }
    });

    test('parses comma-separated allowlist with trim', () {
      final policy = CalleDevicePolicy.parse(
        allowDialRaw: 'false',
        allowlistRaw: ' +15555550100 , +15555550101,',
        allowlistRegionRaw: 'us',
      );

      expect(
        policy.allowlist,
        {'+15555550100', '+15555550101'},
      );
      expect(policy.allowlistRegion, 'US');
    });

    test('empty allowlist region defaults to US', () {
      final policy = CalleDevicePolicy.parse(
        allowDialRaw: '',
        allowlistRaw: '',
        allowlistRegionRaw: '  ',
      );

      expect(policy.allowlist, isEmpty);
      expect(policy.allowlistRegion, 'US');
    });
  });
}
