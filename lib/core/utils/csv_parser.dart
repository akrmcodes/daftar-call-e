import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:daftar/domain/enums/transaction_type.dart';
import 'package:daftar/domain/value_objects/currency_precision.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:intl/intl.dart';

/// How decoded CSV bytes are interpreted before splitting rows.
enum CsvDecodingMode {
  /// BOM-aware UTF‑8, strict UTF‑8, then Windows‑1256 fallback (current heuristic).
  auto,

  /// Strict UTF‑8 after BOM strip — fails when bytes are not valid UTF‑8.
  utf8,

  /// Decode raw bytes as Windows‑1256 (Arabic Windows code page).
  windows1256,
}

/// RFC 4180 CSV handling: byte decoding (UTF‑8 / Windows‑1256), BOM stripping,
/// and CSV-to-list conversion.
///
/// Detection order when [CsvDecodingMode.auto]:
/// - UTF‑8 BOM `EF BB BF`: strip bytes, decode remainder as strict UTF‑8.
/// - Otherwise `utf8.decode(..., allowMalformed: false)` on the full buffer.
/// - On [FormatException], decode **original** bytes as Windows‑1256
///   (`enough_convert`).
///
/// Rows use [Csv.decode] with `dynamicTyping: false` (RFC-aligned; same role as
/// legacy `CsvToListConverter`).

abstract final class CsvParserUtil {
  CsvParserUtil._();

  static const Windows1256Codec _win1256 = Windows1256Codec(
    allowInvalid: true,
  );

  static final Csv _csvRfc = Csv();

  static Future<CsvStructuralParseOutput> parseCsvBytesStructured(
    Uint8List bytes, {
    CsvDecodingMode decodingMode = CsvDecodingMode.auto,
  }) {
    final owned = Uint8List.fromList(bytes);

    return Isolate.run(() {
      final rows = parseCsvRowsSync(owned, decodingMode: decodingMode);
      return structuralParseDecodedRows(rows);
    });
  }

  /// Synchronous decode + CSV split — use from tests or when already isolated.

  static List<List<dynamic>> parseCsvRowsSync(
    Uint8List bytes, {
    CsvDecodingMode decodingMode = CsvDecodingMode.auto,
  }) {
    final text = decodeCsvBytes(bytes, mode: decodingMode);

    if (text.trim().isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    return csvStringToRowTable(text);
  }

  /// Decodes raw CSV bytes according to [mode].

  static String decodeCsvBytes(Uint8List raw, {required CsvDecodingMode mode}) {
    switch (mode) {
      case CsvDecodingMode.auto:
        return decodeCsvBytesWithHeuristic(raw);
      case CsvDecodingMode.utf8:
        return decodeCsvBytesForcedUtf8(raw);
      case CsvDecodingMode.windows1256:
        final decoded = _win1256.decode(raw);

        return _stripBomCharacters(decoded);
    }
  }

  /// UTF‑8 BOM / strict UTF‑8 / Windows‑1256 heuristic with U+FEFF stripping.

  static String decodeCsvBytesWithHeuristic(Uint8List raw) {
    var bytes = raw;

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      bytes = Uint8List.sublistView(bytes, 3);

      final decoded = utf8.decode(bytes, allowMalformed: false);

      return _stripBomCharacters(decoded);
    }

    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);

      return _stripBomCharacters(decoded);
    } on FormatException {
      final fallback = _win1256.decode(raw);

      return _stripBomCharacters(fallback);
    }
  }

  static String decodeCsvBytesForcedUtf8(Uint8List raw) {
    var bytes = raw;

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      bytes = Uint8List.sublistView(bytes, 3);
    }

    try {
      final decoded = utf8.decode(bytes, allowMalformed: false);

      return _stripBomCharacters(decoded);
    } on FormatException catch (e) {
      throw FormatException(
        'CSV bytes are not valid UTF‑8 with BOM stripped (${e.message}).',
      );
    }
  }

  static String _stripBomCharacters(String text) =>
      text.isNotEmpty && text.codeUnitAt(0) == 0xfeff
      ? text.substring(1)
      : text;

  /// Parses decoded CSV source into rows.

  static List<List<dynamic>> csvStringToRowTable(String text) {
    try {
      return _csvRfc.decode(text);
    } on FormatException catch (e) {
      throw FormatException('CSV parse failed: ${e.message}');
    }
  }

  /// Maps decoded CSV rows into a header-aligned table for bounded imports.

  static CsvStructuralParseOutput structuralParseDecodedRows(
    List<List<dynamic>> rows,
  ) {
    if (rows.isEmpty) {
      return CsvStructuralParseOutput.fatal(
        fatalMessage: 'CSV contained no rows.',
      );
    }

    final headerRow = rows.first
        .map(cellToTrimmedString)
        .toList(growable: false);

    if (headerRow.every((element) => element.isEmpty)) {
      return CsvStructuralParseOutput.fatal(
        fatalMessage: 'CSV header row is empty.',
      );
    }

    final width = headerRow.length;

    final body = <List<String>>[];

    var index = 1;

    while (index < rows.length) {
      final rawCells = rows[index];

      final cells = <String>[];

      var col = 0;

      while (col < width) {
        cells.add(
          cellToTrimmedString(
            col < rawCells.length ? rawCells[col] : '',
          ),
        );

        col++;
      }

      body.add(cells);

      index++;
    }

    return CsvStructuralParseOutput(
      headers: headerRow,

      bodyRows: body,
    );
  }

  /// Converts heterogeneous CSV cells to trimmed display strings without [double].
  static String cellToTrimmedString(Object? raw) => '${raw ?? ''}'.trim();

  /// Normalizes Arabic-Indic and Eastern-Arabic digits to ASCII digits.
  static String normalizeDigitsForParse(String raw) {
    final buffer = StringBuffer();
    for (final unit in raw.runes) {
      buffer.write(charFromDigitRune(unit));
    }
    return buffer.toString();
  }

  static String charFromDigitRune(int unit) {
    if (unit >= 0x0660 && unit <= 0x0669) {
      return String.fromCharCode('0'.codeUnitAt(0) + (unit - 0x0660));
    }
    if (unit >= 0x06F0 && unit <= 0x06F9) {
      return String.fromCharCode('0'.codeUnitAt(0) + (unit - 0x06F0));
    }
    return String.fromCharCode(unit);
  }

  /// Returns minor-unit amount ([int]) for [raw] given ISO-like [currencyCode].
  /// Never uses floating-point monetary storage.
  static int? parseAmountToMinorUnits(String raw, String currencyCode) {
    return parseAmountToMinorUnitsWithFractionDigits(
      raw,
      currencyMinorFractionDigits(currencyCode),
    );
  }

  /// Parses [raw] into minor units using an explicit [fractionDigits] count.
  static int? parseAmountToMinorUnitsWithFractionDigits(
    String raw,
    int fractionDigits,
  ) {
    var asciiDigits = normalizeDigitsForParse(raw);
    asciiDigits = asciiDigits
        .replaceAll('\u066c', '')
        .replaceAll('\u060c', ',');
    return _parseMinorUnitsCore(asciiDigits, fractionDigits);
  }

  static int currencyMinorFractionDigits(String currencyCode) {
    return CurrencyPrecision.decimalPlacesForCode(currencyCode);
  }

  /// Parses monetary CSV fields that may contain grouping commas or one decimal separator.
  static int? _parseMinorUnitsCore(String raw, int fractionDigits) {
    var scratch = raw.replaceAll(RegExp(r'[\s\u00a0\u202f]+'), '').trim();

    var neg = false;
    while (scratch.isNotEmpty &&
        (scratch.startsWith('+') || scratch.startsWith('-'))) {
      neg = neg ^ scratch.startsWith('-');
      scratch = scratch.substring(1).trimLeft();
    }

    final normalizedDigitsOnly = scratch.replaceAll(RegExp(r'[^\d,\.]'), '');
    var normalized = normalizedDigitsOnly.trim();
    if (normalized.isEmpty) {
      return null;
    }

    normalized = normalized.replaceFirst(RegExp(r'^[^\d]+'), '').trimRight();
    if (normalized.isEmpty) {
      return null;
    }

    final comma = normalized.lastIndexOf(',');
    final dot = normalized.lastIndexOf('.');
    String invariant;

    if (comma >= 0 && dot >= 0) {
      if (comma > dot) {
        final withoutDots = normalized.replaceAll('.', '');
        invariant = withoutDots.replaceAll(',', '.');
      } else {
        invariant = normalized.replaceAll(',', '');
      }
    } else if (comma >= 0) {
      final after = normalized.substring(comma + 1);
      if (_onlyDigits(after) &&
          after.isNotEmpty &&
          after.length <= fractionDigits &&
          !_looksLikeThousandsPattern(normalized, comma)) {
        invariant =
            '${normalized.substring(0, comma)}.${normalized.substring(comma + 1)}';
      } else {
        invariant = normalized.replaceAll(',', '');
      }
    } else {
      invariant = normalized;
    }

    invariant = invariant.replaceFirst(RegExp(r'^\.+|\.+$'), '').trim();

    final dotIdx = invariant.indexOf('.');
    String integerPartString;
    String fractionalPartRaw;

    if (dotIdx == -1) {
      integerPartString = invariant;
      fractionalPartRaw = '';
    } else {
      integerPartString = invariant.substring(0, dotIdx);
      fractionalPartRaw = invariant.substring(dotIdx + 1);
    }

    if (fractionalPartRaw.contains('.') ||
        !_onlyDigits(integerPartString) ||
        fractionalPartRaw.isNotEmpty &&
            fractionalPartRaw
                .split('.')
                .any((segment) => !_onlyDigits(segment))) {
      return null;
    }

    if (fractionalPartRaw.length > fractionDigits) {
      return null;
    }

    final fracPadded = fractionalPartRaw
        .padRight(fractionDigits, '0')
        .substring(0, fractionDigits);

    integerPartString = integerPartString.isEmpty ? '0' : integerPartString;

    BigInt minor;
    try {
      final whole = BigInt.parse(integerPartString);
      minor = whole * BigInt.from(10).pow(fractionDigits);
      minor += fracPadded.isEmpty ? BigInt.zero : BigInt.parse(fracPadded);
    } on FormatException {
      return null;
    }

    final maxMinor = BigInt.from(9223372036854775807);
    if (minor > maxMinor) {
      return null;
    }

    var minorInt = minor.toInt();
    if (neg && minorInt != 0) {
      minorInt = -minorInt;
    }

    return minorInt;
  }

  static bool _looksLikeThousandsPattern(String value, int lastCommaIdx) {
    final afterComma = lastCommaIdx < value.length - 1
        ? value.substring(lastCommaIdx + 1)
        : '';
    final beforeComma = lastCommaIdx > 0
        ? value.substring(0, lastCommaIdx)
        : '';
    if (!_onlyDigits(afterComma) || !_onlyDigits(beforeComma)) {
      return false;
    }
    if (afterComma.length == 3 && beforeComma.isNotEmpty) {
      return true;
    }
    return false;
  }

  static bool _onlyDigits(String value) {
    if (value.isEmpty) {
      return true;
    }

    return value
        .split('')
        .every(
          (char) => char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39,
        );
  }

  /// Best-effort date parsing for messy CSV exports.
  static DateTime? parseCsvDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalizedDigits = normalizeDigitsForParse(trimmed);

    final iso = DateTime.tryParse(normalizedDigits);
    if (iso != null) {
      return DateTime.utc(
        iso.year,
        iso.month,
        iso.day,
        iso.hour,
        iso.minute,
        iso.second,
        iso.millisecond,
        iso.microsecond,
      );
    }

    final patterns = <String>[
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'dd.MM.yyyy',
    ];

    for (final pattern in patterns) {
      try {
        final parsed = DateFormat(pattern).parseStrict(normalizedDigits);
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
        );
      } on Object {
        continue;
      }
    }

    return null;
  }

  /// Maps human-readable type labels to [TransactionType].
  static TransactionType? parseTransactionType(String raw) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) {
      return null;
    }

    const debtKeys = <String>{
      'debt',
      'd',
      'debit',
      'owe',
      'owed',
      'عليه',
      'دين',
      'ذمة',
    };
    const paymentKeys = <String>{
      'payment',
      'p',
      'pay',
      'paid',
      'credit',
      'له',
      'سداد',
      'دفع',
    };

    if (debtKeys.contains(key)) {
      return TransactionType.debt;
    }
    if (paymentKeys.contains(key)) {
      return TransactionType.payment;
    }
    return null;
  }
}

/// Output of structural CSV parsing (no domain writes).
final class CsvStructuralParseOutput {
  const CsvStructuralParseOutput({
    required this.headers,
    required this.bodyRows,
    this.fatalMessage,
  });

  factory CsvStructuralParseOutput.fatal({required String fatalMessage}) =>
      CsvStructuralParseOutput(
        headers: const <String>[],
        bodyRows: const <List<String>>[],
        fatalMessage: fatalMessage,
      );

  final List<String> headers;
  final List<List<String>> bodyRows;
  final String? fatalMessage;

  bool get isFatal => fatalMessage != null && fatalMessage!.isNotEmpty;
}
