import 'package:daftar/core/utils/deep_link_token_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JoinWorkspace token parsing', () {
    test('accepts full https invite URL', () {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      final parsed = DeepLinkTokenParser.extractFromRaw(
        'https://daftar.app/i/$token',
      );
      expect(parsed, token);
    });

    test('accepts bare token', () {
      const token = 'abcdefghijklmnopqrstuvwxyz012345';
      expect(DeepLinkTokenParser.extractFromRaw(token), token);
    });

    test('rejects short codes', () {
      expect(DeepLinkTokenParser.extractFromRaw('short'), isNull);
    });
  });
}
