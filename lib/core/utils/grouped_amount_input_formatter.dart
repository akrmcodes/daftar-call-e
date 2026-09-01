import 'package:daftar/core/constants/app_constants.dart';
import 'package:daftar/core/utils/csv_parser.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats numeric amount input with thousands grouping as the user types.
///
/// When [allowDecimal] is false, only whole digits are accepted and grouped
/// with the locale thousands separator (comma for [AppConstants.numeralLocale]).
///
/// When [allowDecimal] is true, a single decimal separator is preserved and
/// the integer portion is grouped while the fractional portion is capped at
/// [maxFractionDigits].
class GroupedAmountInputFormatter extends TextInputFormatter {
  const GroupedAmountInputFormatter({
    this.allowDecimal = false,
    this.maxFractionDigits = 0,
  });

  final bool allowDecimal;
  final int maxFractionDigits;

  static final RegExp _groupingSeparators = RegExp(r'[\s\u00a0\u202f,٬،]');
  static final RegExp _nonDigits = RegExp(r'[^\d]');
  static final NumberFormat _groupingFormat =
      NumberFormat.decimalPattern(AppConstants.numeralLocale);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) {
      return TextEditingValue.empty;
    }

    final normalized = CsvParserUtil.normalizeDigitsForParse(raw);
    final formatted = allowDecimal
        ? _formatDecimal(normalized)
        : _formatInteger(normalized);

    if (formatted.isEmpty) {
      return TextEditingValue.empty;
    }

    final selectionOffset = _resolveSelectionOffset(
      source: raw,
      formatted: formatted,
      selection: newValue.selection,
      allowDecimal: allowDecimal,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }

  String _formatInteger(String normalized) {
    final digitsOnly = normalized.replaceAll(_nonDigits, '');
    if (digitsOnly.isEmpty) {
      return '';
    }

    final trimmedLeadingZeros = digitsOnly.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final canonical = trimmedLeadingZeros.isEmpty ? '0' : trimmedLeadingZeros;
    final parsed = int.tryParse(canonical);
    if (parsed == null) {
      return canonical;
    }

    return _groupingFormat.format(parsed);
  }

  String _formatDecimal(String normalized) {
    final withoutGrouping = normalized.replaceAll(_groupingSeparators, '');
    final canonical = withoutGrouping
        .replaceAll('٫', '.')
        .replaceAll('،', '.');

    final dotIndex = canonical.indexOf('.');
    final hasDecimal = dotIndex >= 0;
    final trailingDot = hasDecimal && dotIndex == canonical.length - 1;

    final integerRaw = (hasDecimal ? canonical.substring(0, dotIndex) : canonical)
        .replaceAll(_nonDigits, '');
    var fractionalRaw = hasDecimal
        ? canonical.substring(dotIndex + 1).replaceAll(_nonDigits, '')
        : '';

    if (maxFractionDigits <= 0) {
      fractionalRaw = '';
    } else if (fractionalRaw.length > maxFractionDigits) {
      fractionalRaw = fractionalRaw.substring(0, maxFractionDigits);
    }

    if (integerRaw.isEmpty && fractionalRaw.isEmpty && !trailingDot) {
      return '';
    }

    final trimmedInteger = integerRaw.isEmpty
        ? '0'
        : integerRaw.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final canonicalInteger = trimmedInteger.isEmpty ? '0' : trimmedInteger;
    final parsedInteger = int.tryParse(canonicalInteger);
    final formattedInteger = parsedInteger == null
        ? canonicalInteger
        : _groupingFormat.format(parsedInteger);

    if (trailingDot) {
      return '$formattedInteger.';
    }
    if (fractionalRaw.isEmpty) {
      return formattedInteger;
    }
    return '$formattedInteger.$fractionalRaw';
  }

  int _resolveSelectionOffset({
    required String source,
    required String formatted,
    required TextSelection selection,
    required bool allowDecimal,
  }) {
    final cursor = selection.baseOffset.clamp(0, source.length);
    final digitsBeforeCursor = _digitsBefore(source, cursor);

    if (!allowDecimal) {
      return _offsetAfterDigitCount(formatted, digitsBeforeCursor);
    }

    final decimalIndex = _decimalSeparatorIndex(source);
    if (decimalIndex == -1 || cursor <= decimalIndex) {
      return _offsetAfterDigitCount(formatted, digitsBeforeCursor);
    }

    final formattedDecimalIndex = formatted.indexOf('.');
    if (formattedDecimalIndex == -1) {
      return formatted.length;
    }

    final integerDigitsBeforeDecimal =
        _digitsBefore(source, decimalIndex.clamp(0, source.length));
    final fractionalDigitsBeforeCursor =
        _digitsBefore(source, cursor) - integerDigitsBeforeDecimal;

    return (formattedDecimalIndex + 1 + fractionalDigitsBeforeCursor)
        .clamp(0, formatted.length);
  }

  int _decimalSeparatorIndex(String source) {
    final normalized = CsvParserUtil.normalizeDigitsForParse(source)
        .replaceAll(_groupingSeparators, '')
        .replaceAll('٫', '.')
        .replaceAll('،', '.');
    return normalized.indexOf('.');
  }

  int _digitsBefore(String source, int end) {
    final limit = end.clamp(0, source.length);
    var count = 0;
    for (var i = 0; i < limit; i++) {
      if (_isDigit(source[i])) {
        count++;
      }
    }
    return count;
  }

  int _offsetAfterDigitCount(String formatted, int digitCount) {
    if (digitCount <= 0) {
      return 0;
    }

    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (_isDigit(formatted[i])) {
        seen++;
        if (seen == digitCount) {
          return i + 1;
        }
      }
    }
    return formatted.length;
  }

  bool _isDigit(String char) {
    if (char.isEmpty) {
      return false;
    }
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 0x0660 && code <= 0x0669) ||
        (code >= 0x06F0 && code <= 0x06F9);
  }
}
