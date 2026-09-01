import 'package:daftar/domain/value_objects/currency_precision.dart';

/// Snaps Gemini `amountMinor` to the spoken major amount in [goalText].
///
/// Twin of `parse_spoken_major` / `correct_zero_decimal_scale` in
/// `agent/closing_agent/proposal.py`. Integer-only. Does not invent amounts.
///
/// When [contactHint] is found, parses only the slice until the next sibling
/// name. If the hint is missing, keeps the global snap only when the amount
/// still matches `expected` / ×10 / ×100.
///
/// Parses a spoken major `S`. Expected minor units are `S * 10^exponent` for
/// [currencyCode]. If the proposal amount is `expected`, `expected * 10`, or
/// `expected * 100`, returns `expected`. If it equals `S` and the currency
/// has more than 0 decimal places (Gemini sent major units as minor), scale
/// up to `expected`. Digit strings such as `"10000"` are left alone when they
/// already match `expected`.
int correctSpokenAmountMinor({
  required String goalText,
  required String currencyCode,
  required int amountMinor,
  String? contactHint,
  List<String> siblingHints = const [],
}) {
  final slice = _goalSliceForHint(
    goalText: goalText,
    siblingHints: siblingHints,
    contactHint: contactHint,
  );
  final spoken = parseSpokenMajor(slice ?? goalText);
  if (spoken == null || spoken <= 0) {
    return amountMinor;
  }
  final factor = CurrencyPrecision.minorUnitFactor(
    CurrencyPrecision.decimalPlacesForCode(currencyCode),
  );
  final expected = spoken * factor;
  if (amountMinor == expected ||
      amountMinor == expected * 10 ||
      amountMinor == expected * 100) {
    return expected;
  }
  if (factor > 1 && amountMinor == spoken) {
    return expected;
  }
  return amountMinor;
}

String? _goalSliceForHint({
  required String goalText,
  required List<String> siblingHints,
  String? contactHint,
}) {
  final hintRaw = contactHint?.trim() ?? '';
  if (hintRaw.isEmpty) {
    return null;
  }
  final goalFolded = _normalizeSpokenText(goalText).toLowerCase();
  final hintFolded = _normalizeSpokenText(hintRaw).toLowerCase();
  if (hintFolded.isEmpty) {
    return null;
  }
  final siblingFolded = <String>[
    for (final sibling in siblingHints)
      if (sibling.trim().isNotEmpty)
        _normalizeSpokenText(sibling.trim()).toLowerCase(),
  ].where((folded) => folded.isNotEmpty && folded != hintFolded).toList();
  final start = _findHintIndex(goalFolded, hintFolded, siblingFolded);
  if (start < 0) {
    return null;
  }
  var end = goalFolded.length;
  final after = start + hintFolded.length;
  final suffix = goalFolded.substring(after);
  for (final sibling in siblingFolded) {
    final pos = _findHintIndex(suffix, sibling, siblingFolded);
    if (pos >= 0) {
      final absPos = after + pos;
      if (absPos < end) {
        end = absPos;
      }
    }
  }
  return goalFolded.substring(start, end);
}

int _findHintIndex(String haystack, String needle, List<String> siblings) {
  if (needle.isEmpty) {
    return -1;
  }
  var start = 0;
  while (true) {
    final pos = haystack.indexOf(needle, start);
    if (pos < 0) {
      return -1;
    }
    final shadowed = siblings.any(
      (sibling) =>
          sibling.length > needle.length &&
          sibling.startsWith(needle) &&
          haystack.startsWith(sibling, pos),
    );
    if (!shadowed) {
      return pos;
    }
    start = pos + 1;
  }
}

/// Spoken whole major amount in [goalText], or null if none.
///
/// Order: mixed digit+scale, EN/AR words, currency-anchored digit, last
/// integer (years skipped when another integer exists).
int? parseSpokenMajor(String goalText) {
  final normalized = _normalizeSpokenText(goalText);
  if (normalized.isEmpty) {
    return null;
  }
  return _fromMixedDigitScale(normalized) ??
      _fromEnglishWords(normalized) ??
      _fromArabicWords(normalized) ??
      _fromCurrencyAnchoredDigit(normalized) ??
      _lastWholeInteger(normalized);
}

/// Eastern digits, alef-fold, strip separators/tatweel/tashkeel.
/// Does not map ة→ه (that would destroy مائة).
String _normalizeSpokenText(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + (rune - 0x0660));
      continue;
    }
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + (rune - 0x06F0));
      continue;
    }
    if (rune == 0x0622 || rune == 0x0623 || rune == 0x0625 || rune == 0x0671) {
      buffer.writeCharCode(0x0627);
      continue;
    }
    if (rune == 0x0640 || (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670) {
      continue;
    }
    if (rune == 0x002C || rune == 0x066C || rune == 0x060C || rune == 0x5F) {
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

final _wholeInt = RegExp(r'(?<![\d.])(\d+)(?![\d.])');

final _mixedDigitScaleEn = RegExp(
  r'(\d+)\s*(hundreds?|thousands?|millions?|k)\b',
  caseSensitive: false,
);

final _mixedDigitScaleAr = RegExp(
  r'(\d+)\s*(مائة|مئة|ميه|مية|مئه|الاف|الف|مليون)(?![\u0600-\u06FF])',
);

final _currencyEn = RegExp(
  r'(\d+)\s*(?:riyals?|yer|sar|usd)\b|(?:riyals?|yer|sar|usd)\b\s*(\d+)',
  caseSensitive: false,
);

final _currencyAr = RegExp(r'(\d+)\s*ريال|ريال\s*(\d+)');

final _gluedHundred = RegExp(
  '^(اثنين|اثنان|اثنتين|اتنين|ثلاثة|ثلاث|اربعة|اربع|خمسة|خمس|ستة|ست|سبعة|سبع|ثمانية|ثماني|ثمان|تسعة|تسع)'
  r'(مائة|مئة|ميه|مية|مئه)$',
);

int? _fromMixedDigitScale(String text) {
  final matches = <RegExpMatch>[
    ..._mixedDigitScaleEn.allMatches(text),
    ..._mixedDigitScaleAr.allMatches(text),
  ]..sort((a, b) => a.start.compareTo(b.start));
  if (matches.isEmpty) {
    return null;
  }
  final match = matches.last;
  final n = int.tryParse(match.group(1)!);
  if (n == null || n <= 0) {
    return null;
  }
  final scale = _scaleFor(match.group(2)!.toLowerCase());
  if (scale == null) {
    return null;
  }
  final value = n * scale;
  return value > 0 ? value : null;
}

int? _scaleFor(String token) {
  switch (token) {
    case 'hundred':
    case 'hundreds':
    case 'مائة':
    case 'مئة':
    case 'ميه':
    case 'مية':
    case 'مئه':
      return 100;
    case 'thousand':
    case 'thousands':
    case 'k':
    case 'الف':
    case 'الاف':
      return 1000;
    case 'million':
    case 'millions':
    case 'مليون':
      return 1000000;
    default:
      return null;
  }
}

int? _fromCurrencyAnchoredDigit(String text) {
  final matches = <RegExpMatch>[
    ..._currencyEn.allMatches(text),
    ..._currencyAr.allMatches(text),
  ]..sort((a, b) => a.start.compareTo(b.start));
  for (var i = matches.length - 1; i >= 0; i--) {
    final match = matches[i];
    final raw = match.group(1) ?? match.group(2);
    final value = int.tryParse(raw ?? '');
    if (value != null && value > 0) {
      return value;
    }
  }
  return null;
}

int? _lastWholeInteger(String text) {
  final values = <int>[];
  for (final match in _wholeInt.allMatches(text)) {
    final value = int.tryParse(match.group(1)!);
    if (value != null && value > 0) {
      values.add(value);
    }
  }
  if (values.isEmpty) {
    return null;
  }
  final nonYears = [
    for (final value in values)
      if (!_isYear(value)) value,
  ];
  if (nonYears.isNotEmpty) {
    return nonYears.last;
  }
  return values.last;
}

bool _isYear(int value) => value >= 1900 && value <= 2100;

const _enOnes = <String, int>{
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const _enTens = <String, int>{
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

int? _fromEnglishWords(String text) {
  final tokens = RegExp(
    '[a-z]+',
    caseSensitive: false,
  ).allMatches(text.toLowerCase()).map((m) => m.group(0)!).toList();
  var total = 0;
  var current = 0;
  var found = false;
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (token == 'and') {
      continue;
    }
    if (token == 'a' || token == 'an') {
      final next = i + 1 < tokens.length ? tokens[i + 1] : '';
      if (next == 'hundred' ||
          next == 'hundreds' ||
          next == 'thousand' ||
          next == 'thousands' ||
          next == 'million' ||
          next == 'millions') {
        current += 1;
        found = true;
      }
      continue;
    }
    final one = _enOnes[token];
    if (one != null) {
      current += one;
      found = true;
      continue;
    }
    final ten = _enTens[token];
    if (ten != null) {
      current += ten;
      found = true;
      continue;
    }
    if (token == 'hundred' || token == 'hundreds') {
      current = (current == 0 ? 1 : current) * 100;
      found = true;
      continue;
    }
    if (token == 'thousand' || token == 'thousands') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      found = true;
      continue;
    }
    if (token == 'million' || token == 'millions') {
      total += (current == 0 ? 1 : current) * 1000000;
      current = 0;
      found = true;
    }
  }
  if (!found) {
    return null;
  }
  final value = total + current;
  return value > 0 ? value : null;
}

const _arOnes = <String, int>{
  'واحد': 1,
  'واحدة': 1,
  'احد': 1,
  'اثنين': 2,
  'اثنان': 2,
  'اثنتين': 2,
  'اتنين': 2,
  'ثلاثة': 3,
  'ثلاث': 3,
  'اربعة': 4,
  'اربع': 4,
  'خمسة': 5,
  'خمس': 5,
  'ستة': 6,
  'ست': 6,
  'سبعة': 7,
  'سبع': 7,
  'ثمانية': 8,
  'ثماني': 8,
  'ثمان': 8,
  'تسعة': 9,
  'تسع': 9,
  'عشرة': 10,
  'عشر': 10,
};

const _arTens = <String, int>{
  'عشرون': 20,
  'عشرين': 20,
  'ثلاثون': 30,
  'ثلاثين': 30,
  'اربعون': 40,
  'اربعين': 40,
  'خمسون': 50,
  'خمسين': 50,
  'ستون': 60,
  'ستين': 60,
  'سبعون': 70,
  'سبعين': 70,
  'ثمانون': 80,
  'ثمانين': 80,
  'تسعون': 90,
  'تسعين': 90,
};

const _arHundred = <String, int>{
  'مئة': 100,
  'مائة': 100,
  'مائه': 100,
  'مئه': 100,
  'ميه': 100,
  'مية': 100,
  'مئتان': 200,
  'مائتان': 200,
  'مئتين': 200,
  'مائتين': 200,
  'ميتين': 200,
};

const _arThousand = <String, int>{
  'الف': 1000,
  'الاف': 1000,
  'الفان': 2000,
  'الفين': 2000,
};

const _arMillion = <String, int>{
  'مليون': 1000000,
  'ملايين': 1000000,
  'مليونين': 2000000,
  'مليونان': 2000000,
};

int? _fromArabicWords(String text) {
  final tokens = RegExp(
    r'[\u0600-\u06FF]+',
  ).allMatches(text).map((m) => m.group(0)!).toList();
  var total = 0;
  var current = 0;
  var found = false;
  for (final raw in tokens) {
    final token = _unwrapArabicWaw(raw);
    if (token == 'و') {
      continue;
    }
    final glued = _gluedArabicHundred(token);
    if (glued != null) {
      current += glued;
      found = true;
      continue;
    }
    final one = _arOnes[token];
    if (one != null) {
      current += one;
      found = true;
      continue;
    }
    final ten = _arTens[token];
    if (ten != null) {
      current += ten;
      found = true;
      continue;
    }
    final hundred = _arHundred[token];
    if (hundred != null) {
      if (hundred == 200) {
        current = 200;
      } else {
        current = (current == 0 ? 1 : current) * 100;
      }
      found = true;
      continue;
    }
    final thousand = _arThousand[token];
    if (thousand != null) {
      if (thousand == 2000) {
        total += 2000;
      } else {
        total += (current == 0 ? 1 : current) * 1000;
      }
      current = 0;
      found = true;
      continue;
    }
    final million = _arMillion[token];
    if (million != null) {
      if (million == 2000000) {
        total += 2000000;
      } else {
        total += (current == 0 ? 1 : current) * 1000000;
      }
      current = 0;
      found = true;
    }
  }
  if (!found) {
    return null;
  }
  final value = total + current;
  return value > 0 ? value : null;
}

/// Strip a leading glued و when the remainder is a number word.
/// Leaves واحد / واحدة intact because they already match.
String _unwrapArabicWaw(String token) {
  if (_isArabicAmountToken(token)) {
    return token;
  }
  if (token.startsWith('و') && token.length > 1) {
    final rest = token.substring(1);
    if (_isArabicAmountToken(rest)) {
      return rest;
    }
  }
  return token;
}

bool _isArabicAmountToken(String token) {
  return _arOnes.containsKey(token) ||
      _arTens.containsKey(token) ||
      _arHundred.containsKey(token) ||
      _arThousand.containsKey(token) ||
      _arMillion.containsKey(token) ||
      _gluedArabicHundred(token) != null;
}

int? _gluedArabicHundred(String token) {
  final match = _gluedHundred.firstMatch(token);
  if (match == null) {
    return null;
  }
  final prefix = match.group(1);
  if (prefix == null || prefix.isEmpty) {
    return 100;
  }
  final ones = _arOnes[prefix];
  if (ones == null) {
    return null;
  }
  return ones * 100;
}
