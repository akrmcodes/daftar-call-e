import 'package:daftar/presentation/screens/premium/widgets/activation_code_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ActivationCodeInput.format', () {
    test('formats Pro+ with prefix and body groups of 4', () {
      expect(
        ActivationCodeInput.format('PROPLUSWL9XM3JJLSJQ23DE'),
        'PROPLUS-WL9X-M3JJ-LSJQ-23DE',
      );
    });

    test('formats Pro with prefix and body groups of 4', () {
      expect(
        ActivationCodeInput.format('PROFUP9LFNCTQJ8'),
        'PRO-FUP9-LFNC-TQJ8',
      );
    });

    test('keeps incomplete PROPLUS prefix without early PRO dash', () {
      expect(ActivationCodeInput.format('PROP'), 'PROP');
      expect(ActivationCodeInput.format('PROPLU'), 'PROPLU');
    });

    test('formats generic online code in groups of 4', () {
      expect(ActivationCodeInput.format('ABCD1234EFGH'), 'ABCD-1234-EFGH');
    });
  });

  group('ActivationCodeInput.normalize', () {
    test('preserves PROPLUS hyphen for offline validator', () {
      expect(
        ActivationCodeInput.normalize('PROPLUS-WL9X-M3JJ-LSJQ-23DE'),
        'PROPLUS-WL9XM3JJLSJQ23DE',
      );
    });

    test('preserves PRO hyphen for offline validator', () {
      expect(
        ActivationCodeInput.normalize('PRO-FUP9-LFNC-TQJ8'),
        'PRO-FUP9LFNCTQJ8',
      );
    });

    test('checks PROPLUS before PRO', () {
      expect(
        ActivationCodeInput.normalize('propluswl9xm3jjlsjq23de'),
        'PROPLUS-WL9XM3JJLSJQ23DE',
      );
    });
  });
}
