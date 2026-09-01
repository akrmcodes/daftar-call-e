import 'package:daftar/core/extensions/string_extensions.dart';

/// True when [hint] is the same full display name as [displayName].
///
/// Uses `normalizeArabic` (alef-fold, diacritics, collapsed spaces)
/// then case-fold. Prefix / FTS uniqueness is **not** exact — "Mohammed"
/// does not match "Mohammed Waleed". Alias groups are not exact either.
bool isExactContactNameMatch(String hint, String displayName) {
  final left = hint.normalizeArabic().toLowerCase();
  if (left.isEmpty) {
    return false;
  }
  return left == displayName.normalizeArabic().toLowerCase();
}
