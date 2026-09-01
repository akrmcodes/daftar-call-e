import 'dart:convert';
import 'dart:typed_data';

import 'package:daftar/core/utils/csv_parser.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvParserUtil.parseCsvBytesStructured encoding heuristics', () {
    final utf8MixedPlainBytes = Uint8List.fromList(<int>[
      217,
      129,
      216,
      167,
      216,
      170,
      217,
      136,
      216,
      177,
      216,
      169,
      32,
      65,
      112,
      112,
      108,
      101,
      32,
      49,
      53,
      32,
      80,
      114,
      111,
      44,
      53,
      48,
      48,
    ]);
    final cp1256MixedPlainBytes = Uint8List.fromList(<int>[
      221,
      199,
      202,
      230,
      209,
      201,
      32,
      65,
      112,
      112,
      108,
      101,
      32,
      49,
      53,
      32,
      80,
      114,
      111,
      44,
      53,
      48,
      48,
    ]);
    final utf8QuotedEnglishBytes = Uint8List.fromList(<int>[
      34,
      65,
      108,
      105,
      44,
      32,
      77,
      111,
      104,
      97,
      109,
      109,
      97,
      100,
      34,
      44,
      53,
      48,
      48,
    ]);
    final utf8QuotedMixedBytes = Uint8List.fromList(<int>[
      34,
      217,
      129,
      216,
      167,
      216,
      170,
      217,
      136,
      216,
      177,
      216,
      169,
      32,
      65,
      112,
      112,
      108,
      101,
      44,
      32,
      49,
      53,
      32,
      80,
      114,
      111,
      34,
      44,
      53,
      48,
      48,
    ]);
    final cp1256QuotedMixedBytes = Uint8List.fromList(<int>[
      34,
      221,
      199,
      202,
      230,
      209,
      201,
      32,
      65,
      112,
      112,
      108,
      101,
      44,
      32,
      49,
      53,
      32,
      80,
      114,
      111,
      34,
      44,
      53,
      48,
      48,
    ]);

    test(
      'decodes UTF-8 without BOM and preserves mixed Arabic-English text',
      () async {
        final output =
            await CsvParserUtil.parseCsvBytesStructured(utf8MixedPlainBytes);

        expect(output.headers.length, 2);
        expect(output.headers[0], 'فاتورة Apple 15 Pro');
        expect(output.headers[1], '500');
        expect(output.headers[0], isNot(contains('?')));
        expect(output.headers[0], isNot(contains('\uFFFD')));
      },
    );

    test(
      'decodes UTF-8 with EF BB BF BOM and preserves Arabic glyphs',
      () async {
        final payload = utf8.encode('محمد,100');
        final withBom = Uint8List.fromList(<int>[
          0xef,
          0xbb,
          0xbf,
          ...payload,
        ]);

        final output = await CsvParserUtil.parseCsvBytesStructured(withBom);

        expect(output.headers[0], 'محمد');
        expect(output.headers[1], '100');
        expect(output.headers[0], isNot(contains('?')));
        expect(output.headers[0], isNot(contains('\uFFFD')));
      },
    );

    test(
      'decodes Windows-1256 bytes and preserves mixed Arabic-English text',
      () async {
        final output =
            await CsvParserUtil.parseCsvBytesStructured(cp1256MixedPlainBytes);

        expect(output.headers[0], 'فاتورة Apple 15 Pro');
        expect(output.headers[1], '500');
        expect(output.headers[0], isNot(contains('?')));
        expect(output.headers[0], isNot(contains('\uFFFD')));
      },
    );

    test(
      'forced UTF-8 mode rejects CP1256 mixed Arabic-English bytes',
      () async {
        await expectLater(
          CsvParserUtil.parseCsvBytesStructured(
            cp1256MixedPlainBytes,
            decodingMode: CsvDecodingMode.utf8,
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'explicit Windows-1256 mode decodes CP1256 mixed Arabic-English bytes',
      () async {
        final output = await CsvParserUtil.parseCsvBytesStructured(
          cp1256MixedPlainBytes,
          decodingMode: CsvDecodingMode.windows1256,
        );

        expect(output.headers[0], 'فاتورة Apple 15 Pro');
        expect(output.headers[1], '500');
      },
    );

    test(
      'preserves RFC 4180 quoted English comma fields in UTF-8',
      () async {
        final output =
            await CsvParserUtil.parseCsvBytesStructured(utf8QuotedEnglishBytes);

        expect(output.headers.length, 2);
        expect(output.headers[0], 'Ali, Mohammad');
        expect(output.headers[1], '500');
      },
    );

    test(
      'preserves RFC 4180 quoted mixed Arabic-English fields in UTF-8',
      () async {
        final output =
            await CsvParserUtil.parseCsvBytesStructured(utf8QuotedMixedBytes);

        expect(output.headers.length, 2);
        expect(output.headers[0], 'فاتورة Apple, 15 Pro');
        expect(output.headers[1], '500');
        expect(output.headers[0], isNot(contains('?')));
        expect(output.headers[0], isNot(contains('\uFFFD')));
      },
    );

    test(
      'preserves RFC 4180 quoted mixed Arabic-English fields in Windows-1256',
      () async {
        final output = await CsvParserUtil.parseCsvBytesStructured(
          cp1256QuotedMixedBytes,
          decodingMode: CsvDecodingMode.windows1256,
        );

        expect(output.headers.length, 2);
        expect(output.headers[0], 'فاتورة Apple, 15 Pro');
        expect(output.headers[1], '500');
        expect(output.headers[0], isNot(contains('?')));
        expect(output.headers[0], isNot(contains('\uFFFD')));
      },
    );
  });

  group('CsvParserUtil structural parsing', () {
    test('structuralParseDecodedRows pads short rows with empty cells', () {
      final output = CsvParserUtil.structuralParseDecodedRows([
        ['name', 'amount', 'currency'],
        ['أحمد', '500'],
        ['', '100', 'YER', 'extra-ignored'],
      ]);

      expect(output.isFatal, isFalse);
      expect(output.headers, ['name', 'amount', 'currency']);
      expect(output.bodyRows[0], ['أحمد', '500', '']);
      expect(output.bodyRows[1], ['', '100', 'YER']);
    });

    group('Negative and edge cases', () {
      test('structuralParseDecodedRows returns fatal for empty input', () {
        final output = CsvParserUtil.structuralParseDecodedRows([]);

        expect(output.isFatal, isTrue);
        expect(output.fatalMessage, contains('no rows'));
      });

      test('structuralParseDecodedRows returns fatal for blank header row', () {
        final output = CsvParserUtil.structuralParseDecodedRows([
          ['', '  ', ''],
        ]);

        expect(output.isFatal, isTrue);
        expect(output.fatalMessage, contains('header'));
      });

      test('parseCsvRowsSync throws on empty byte buffer', () {
        expect(
          () => CsvParserUtil.parseCsvRowsSync(Uint8List(0)),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });

  group('CsvParserUtil amount and type parsing', () {
    test('parseAmountToMinorUnits handles grouped and fractional formats', () {
      expect(CsvParserUtil.parseAmountToMinorUnits('1,234.56', 'USD'), 123456);
      expect(CsvParserUtil.parseAmountToMinorUnits('15,500', 'YER'), 15500);
      expect(CsvParserUtil.parseAmountToMinorUnits('١٥٠٠', 'YER'), 1500);
    });

    test('parseTransactionType maps Arabic and English labels', () {
      expect(CsvParserUtil.parseTransactionType('دين'), TransactionType.debt);
      expect(CsvParserUtil.parseTransactionType('سداد'), TransactionType.payment);
      expect(CsvParserUtil.parseTransactionType('DEBT'), TransactionType.debt);
    });

    test('parseCsvDate accepts ISO and dd/MM/yyyy', () {
      expect(
        CsvParserUtil.parseCsvDate('2026-06-17')?.toIso8601String(),
        '2026-06-17T00:00:00.000Z',
      );
      expect(
        CsvParserUtil.parseCsvDate('17/06/2026')?.toIso8601String(),
        '2026-06-17T00:00:00.000Z',
      );
    });

    group('Negative and edge cases', () {
      test('parseAmountToMinorUnits rejects garbage and overflow', () {
        expect(CsvParserUtil.parseAmountToMinorUnits('', 'YER'), isNull);
        expect(CsvParserUtil.parseAmountToMinorUnits('abc', 'YER'), isNull);
        expect(
          CsvParserUtil.parseAmountToMinorUnits('1.234', 'YER'),
          isNull,
        );
        expect(
          CsvParserUtil.parseAmountToMinorUnits(
            '999999999999999999999',
            'YER',
          ),
          isNull,
        );
      });

      test('parseTransactionType returns null for unknown labels', () {
        expect(CsvParserUtil.parseTransactionType(''), isNull);
        expect(CsvParserUtil.parseTransactionType('transfer'), isNull);
        expect(CsvParserUtil.parseTransactionType('   '), isNull);
      });

      test('parseCsvDate returns null for unparseable strings', () {
        expect(CsvParserUtil.parseCsvDate(''), isNull);
        expect(CsvParserUtil.parseCsvDate('not-a-date'), isNull);
        expect(CsvParserUtil.parseCsvDate('32/13/2026'), isNull);
      });

      test('normalizeDigitsForParse leaves latin letters untouched', () {
        expect(CsvParserUtil.normalizeDigitsForParse('abc'), 'abc');
      });
    });
  });
}
