import 'dart:convert';

import 'package:daftar/data/datasources/remote/google_id_token_expiry.dart';
import 'package:flutter_test/flutter_test.dart';

String _unsignedJwt({required int exp}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(utf8.encode('{"exp":$exp}'));
  return '$header.$payload.sig';
}

void main() {
  group('googleIdTokenExpiry', () {
    test('decodes JWT exp as UTC DateTime', () {
      final exp = DateTime.utc(2026, 8, 14, 12).millisecondsSinceEpoch ~/ 1000;
      final expiry = googleIdTokenExpiry(_unsignedJwt(exp: exp));

      expect(expiry, DateTime.utc(2026, 8, 14, 12));
    });

    test('returns null for a non-JWT string', () {
      expect(googleIdTokenExpiry('not-a-jwt'), isNull);
    });

    test('decodes JWT sub', () {
      final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"google-sub-123"}'));
      expect(
        googleIdTokenSubject('$header.$payload.sig'),
        'google-sub-123',
      );
    });

    test('returns null sub for a non-JWT string', () {
      expect(googleIdTokenSubject('not-a-jwt'), isNull);
    });

    test('returns null when payload has no exp', () {
      final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
      final payload = base64Url.encode(utf8.encode('{"sub":"abc"}'));
      expect(googleIdTokenExpiry('$header.$payload.sig'), isNull);
    });
  });
}
