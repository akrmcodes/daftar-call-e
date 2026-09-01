import 'package:daftar/application/agent/contact_name_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isExactContactNameMatch', () {
    test('equal full names match after Arabic normalize', () {
      expect(isExactContactNameMatch('أحمد', 'احمد'), isTrue);
      expect(isExactContactNameMatch('Mohammed Waleed', 'mohammed waleed'), isTrue);
    });

    test('prefix is not an exact full-name match', () {
      expect(isExactContactNameMatch('Mohammed', 'Mohammed Waleed'), isFalse);
      expect(isExactContactNameMatch('محمد', 'محمد وليد'), isFalse);
    });

    test('empty hint is never exact', () {
      expect(isExactContactNameMatch('', 'Ali'), isFalse);
      expect(isExactContactNameMatch('   ', 'Ali'), isFalse);
    });
  });
}
