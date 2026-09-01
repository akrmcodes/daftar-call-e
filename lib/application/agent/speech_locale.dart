import 'package:daftar/core/utils/speech_script_locale.dart';

export 'package:daftar/core/utils/speech_script_locale.dart';

final _enToArabic = <RegExp>[
  RegExp(r'\bspeak\s+(in\s+)?arabic\b', caseSensitive: false),
  RegExp(r'\bswitch\s+to\s+arabic\b', caseSensitive: false),
  RegExp(r'\bin\s+arabic\b', caseSensitive: false),
];

final _enToEnglish = <RegExp>[
  RegExp(r'\bspeak\s+(in\s+)?english\b', caseSensitive: false),
  RegExp(r'\bswitch\s+to\s+english\b', caseSensitive: false),
  RegExp(r'\bin\s+english\b', caseSensitive: false),
];

const _arToArabic = <String>[
  'تحدث بالعربية',
  'تحدث بالعربي',
  'احك عربي',
  'احكي عربي',
  'بالعربي',
];

const _arToEnglish = <String>[
  'تحدث بالإنجليزية',
  'تحدث بالانجليزية',
  'احك إنجليزي',
  'احكي إنجليزي',
  'احك انجليزي',
  'احكي انجليزي',
  'بالإنجليزي',
  'بالانجليزي',
];

/// Resolves the session speech locale from an optional override.
String resolveSpeechLocale({
  required String settingsLocale,
  String? override,
}) {
  if (override != null && override.isNotEmpty) {
    return normalizeSpeechLocale(override);
  }
  return normalizeSpeechLocale(settingsLocale);
}

/// Detects an explicit merchant request to speak Arabic or English.
///
/// Returns `ar` / `en`, or null when the transcript is not a language switch.
/// Does not match incidental words such as "Arabic coffee".
String? detectSpeechLocaleSwitch(String transcript) {
  final text = transcript.trim();
  if (text.isEmpty) {
    return null;
  }
  for (final phrase in _arToArabic) {
    if (text.contains(phrase)) {
      return 'ar';
    }
  }
  for (final pattern in _enToArabic) {
    if (pattern.hasMatch(text)) {
      return 'ar';
    }
  }
  for (final phrase in _arToEnglish) {
    if (text.contains(phrase)) {
      return 'en';
    }
  }
  for (final pattern in _enToEnglish) {
    if (pattern.hasMatch(text)) {
      return 'en';
    }
  }
  return null;
}
