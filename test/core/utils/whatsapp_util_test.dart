import 'package:daftar/core/utils/whatsapp_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsAppUtil.sanitizePhone', () {
    test('strips separators and + prefix for Yemen format', () {
      expect(
        WhatsAppUtil.sanitizePhone('+967 77-123-4567'),
        '967771234567',
      );
    });

    test('strips 00 international prefix and formatting for KSA format', () {
      expect(
        WhatsAppUtil.sanitizePhone('00966 (50) 123 4567'),
        '966501234567',
      );
    });

    test('trims surrounding space and normalizes US-style entry', () {
      expect(
        WhatsAppUtil.sanitizePhone('  +1 555 555 0100 '),
        '15555550100',
      );
    });

    test('returns empty when no digits remain', () {
      expect(WhatsAppUtil.sanitizePhone('+-() --'), '');
    });

    test('maps Arabic-Indic digits and strips + prefix', () {
      expect(
        WhatsAppUtil.sanitizePhone('+٩٦٧ ٧٧-١٢٣-٤٥٦٧'),
        '967771234567',
      );
    });

    test('maps Arabic-Indic digits with 00 international prefix', () {
      expect(
        WhatsAppUtil.sanitizePhone('٠٠٩٦٦ (٥٠) ١٢٣ ٤٥٦٧'),
        '966501234567',
      );
    });

    test('preserves national leading zero when no country trunk', () {
      expect(
        WhatsAppUtil.sanitizePhone('٠٧٧١٢٣٤٥٦٧'),
        '0771234567',
      );
    });
  });

  group('WhatsAppUtil native send schemes', () {
    test('native send URIs use digits-only phone query', () {
      expect(
        WhatsAppUtil.nativeBusinessSendUri('967771234567').toString(),
        'whatsapp-smb://send?phone=967771234567',
      );
      expect(
        WhatsAppUtil.nativeConsumerSendUri('966501234567').toString(),
        'whatsapp://send?phone=966501234567',
      );
    });

    test(
      'tryLaunchNativeWhatsAppSendInOrder returns false for empty phone',
      () async {
        expect(
          await WhatsAppUtil.tryLaunchNativeWhatsAppSendInOrder(''),
          false,
        );
      },
    );
  });
}
