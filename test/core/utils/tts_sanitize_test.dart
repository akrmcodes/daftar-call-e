import 'package:daftar/core/utils/tts_sanitize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips markdown asterisks and keeps the words', () {
    expect(sanitizeForTts('**500** for Mohamed'), '500 for Mohamed');
    expect(sanitizeForTts('*bold* juice'), 'bold juice');
    expect(sanitizeForTts('Hello *'), 'Hello');
  });

  test('drops RFC-4122 UUIDs and does not say uuid', () {
    const id = '9135114a-bad1-4415-9ae6-ea4f8c66834f';
    expect(looksLikeUuid(id), isTrue);
    expect(sanitizeForTts(id), isEmpty);
    expect(
      sanitizeForTts('Statement for $id please'),
      'Statement for please',
    );
    expect(
      sanitizeForTts('Statement for $id please').toLowerCase(),
      isNot(contains('uuid')),
    );
  });

  test('expands ampersand and chip middle-dot', () {
    expect(
      sanitizeForTts('Press Create & record debt'),
      'Press Create and record debt',
    );
    expect(sanitizeForTts('Mohamed · Customers'), 'Mohamed, Customers');
  });

  test('expands ampersand to wa in Arabic', () {
    expect(sanitizeForTts('سجل الدين & السداد'), 'سجل الدين و السداد');
  });

  test('strips links, fences, and leftover brackets', () {
    expect(sanitizeForTts('[Mohamed](https://example.com)'), 'Mohamed');
    expect(sanitizeForTts('See (PDF) now'), 'See PDF now');
    expect(nonUuidHint('9135114a-bad1-4415-9ae6-ea4f8c66834f'), isNull);
    expect(nonUuidHint('  Mohamed  '), 'Mohamed');
  });
}
