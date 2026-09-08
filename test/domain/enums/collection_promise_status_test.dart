import 'package:daftar/domain/enums/collection_promise_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CollectionPromiseStatus.isMerchantResolution', () {
    test('terminal statuses are merchant resolutions', () {
      expect(CollectionPromiseStatus.kept.isMerchantResolution, isTrue);
      expect(CollectionPromiseStatus.broken.isMerchantResolution, isTrue);
      expect(CollectionPromiseStatus.cancelled.isMerchantResolution, isTrue);
    });

    test('pending is not a merchant resolution', () {
      expect(CollectionPromiseStatus.pending.isMerchantResolution, isFalse);
    });
  });
}
