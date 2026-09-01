// Strips TTS-hostile markup and identifiers before Chirp / device speech.
// Markdown, UUIDs, leftover `*`, and chip separators must never be voiced.

final _uuid = RegExp(
  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
  '[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}',
);

final _uuidOnly = RegExp(
  '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final _mdImage = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _mdLink = RegExp(r'\[([^\]]+)\]\([^)]*\)');
final _mdFence = RegExp('```[A-Za-z0-9_-]*\n?(.*?)```', dotAll: true);
final _mdInlineCode = RegExp('`+([^`]+)`+');
final _mdStrike = RegExp('~~([^~]+)~~');
final _mdBoldStar = RegExp(r'\*\*+([^*]+)\*\*+');
final _mdBoldUnderscore = RegExp('__([^_]+)__');
final _mdItalicStar = RegExp(
  r'(^|[\s(])\*([^\s*][^*]*?)\*([\s.,!?;:)]|$)',
);
final _mdItalicUnderscore = RegExp(
  r'(^|[\s(])_([^\s_][^_]*?)_([\s.,!?;:)]|$)',
);
final _mdLineLead = RegExp(
  r'^[ \t]*(?:#{1,6}|>+|[-*+]|\d+\.)[ \t]+',
  multiLine: true,
);
final _leftoverMarkup = RegExp('[*_#`~]');
final _brackets = RegExp(r'[\[\]()（）]');
final _multiSpace = RegExp(r'[ \t]{2,}');
final _arabicLetter = RegExp(r'[\u0600-\u06FF]');

/// True when [raw] is a single RFC-4122 UUID (v1–v5).
bool looksLikeUuid(String raw) {
  return _uuidOnly.hasMatch(raw.trim());
}

/// Spoken-name hint, or null when empty / a UUID.
String? nonUuidHint(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty || looksLikeUuid(trimmed)) {
    return null;
  }
  return trimmed;
}

/// Returns Chirp-safe prose. Empty when nothing remains to say.
String sanitizeForTts(String raw) {
  var text = raw.trim();
  if (text.isEmpty) {
    return '';
  }

  text = text.replaceAllMapped(_mdImage, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdLink, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdFence, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdInlineCode, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdStrike, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdBoldStar, (match) => match[1] ?? '');
  text = text.replaceAllMapped(_mdBoldUnderscore, (match) => match[1] ?? '');
  text = text.replaceAllMapped(
    _mdItalicStar,
    (match) => '${match[1]}${match[2]}${match[3]}',
  );
  text = text.replaceAllMapped(
    _mdItalicUnderscore,
    (match) => '${match[1]}${match[2]}${match[3]}',
  );
  text = text.replaceAll(_mdLineLead, '');
  text = text.replaceAll(_uuid, '');
  text = text.replaceAll(_leftoverMarkup, '');
  text = text.replaceAll(_brackets, '');
  text = text.replaceAll(' · ', ', ');
  text = text.replaceAll('·', ', ');
  text = text.replaceAll(
    '&',
    _arabicLetter.hasMatch(text) ? ' و ' : ' and ',
  );
  text = text.replaceAll(_multiSpace, ' ');
  text = text.replaceAll(RegExp('\n{3,}'), '\n\n');
  return text.trim();
}
