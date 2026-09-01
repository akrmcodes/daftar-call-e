/// Chirp 3 HD Enceladus must match the script of the utterance.
///
/// Google does not document `<lang>` for mixed-script Chirp synthesis.
/// One utterance → one language_code. Arabic letters present → `ar`;
/// otherwise Latin letters → `en`. Latin names inside Arabic templates
/// (`Mohamed عليه 500`) stay `ar` so the voice is not forced to en-US.
String normalizeSpeechLocale(String raw) {
  return raw.toLowerCase().startsWith('en') ? 'en' : 'ar';
}

/// Forces [locale] to the script of [text] when letters are present.
String coerceLocaleToTextScript({
  required String locale,
  required String text,
}) {
  var arabic = 0;
  var latin = 0;
  for (final rune in text.runes) {
    if (_isArabicLetter(rune)) {
      arabic += 1;
    } else if (_isLatinLetter(rune)) {
      latin += 1;
    }
  }
  if (arabic > 0) {
    return 'ar';
  }
  if (latin > 0) {
    return 'en';
  }
  return normalizeSpeechLocale(locale);
}

bool _isArabicLetter(int rune) {
  return (rune >= 0x0600 && rune <= 0x06FF) ||
      (rune >= 0x0750 && rune <= 0x077F) ||
      (rune >= 0x08A0 && rune <= 0x08FF) ||
      (rune >= 0xFB50 && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF);
}

bool _isLatinLetter(int rune) {
  return (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
}
