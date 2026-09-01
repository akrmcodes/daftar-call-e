import 'package:daftar/core/utils/play_store_referrer_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayStoreReferrerBuilder', () {
    const token = 'abcdefghijklmnopqrstuvwxyz012345';

    test('buildReferrerParam encodes utm_content token', () {
      final encoded = PlayStoreReferrerBuilder.buildReferrerParam(token);
      expect(
        Uri.decodeComponent(encoded),
        'utm_source=daftar&utm_medium=deep_link&utm_content=$token',
      );
    });

    test('buildPlayStoreUrlWithToken includes package and referrer', () {
      final url = PlayStoreReferrerBuilder.buildPlayStoreUrlWithToken(token);
      final uri = Uri.parse(url);
      expect(uri.host, 'play.google.com');
      expect(uri.queryParameters['id'], PlayStoreReferrerBuilder.playPackageId);
      expect(
        Uri.decodeComponent(uri.queryParameters['referrer']!),
        contains('utm_content=$token'),
      );
    });
  });
}
