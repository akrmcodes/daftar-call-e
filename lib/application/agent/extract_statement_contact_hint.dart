import 'package:daftar/application/agent/arabic_name_particles.dart';

/// Strips statement phrasing from a merchant goal, leaving a contact name hint.
///
/// Token-bounded; does not strip leading `و`/`ل`/`ب`/`ف` from names.
/// `كشف حساب لوليد` still yields `وليد` because `كشف حساب ل` ends in `ل`.
String? extractStatementContactHint(String goalText) {
  final trimmed = goalText.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  const phrases = <String>[
    'statement for',
    'statement of',
    'a statement',
    'statement',
    'كشف الحساب',
    'كشف حساب ل',
    'كشف حساب',
    'كشف',
  ];
  final kept = leftoverNameTokens(trimmed, phrases);
  if (kept.isEmpty) {
    return null;
  }
  return kept.join(' ');
}
