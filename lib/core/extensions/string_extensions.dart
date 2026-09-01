/// Extensions on [String] for Arabic text processing.
///
/// The Arabic normalization pipeline is CRITICAL for full-text search
/// accuracy. Arabic text has many variant forms that represent the same
/// logical character. Without normalization, searching for "احمد" would
/// not match "أحمد" or "أَحْمَد".
///
/// ## Normalization Pipeline
/// 1. Strip diacritics (تشكيل): U+064B–U+065F, U+0670
/// 2. Normalize Alef variants: أ إ آ ٱ → ا
/// 3. Normalize Taa Marbuta: ة → ه
/// 4. Normalize Alef Maqsura: ى → ي
/// 5. Trim and collapse whitespace
extension ArabicNormalization on String {
  // ── Diacritics (Tashkeel) Unicode Range ─────────────────────────────
  // U+064B FATHATAN    ً
  // U+064C DAMMATAN    ٌ
  // U+064D KASRATAN    ٍ
  // U+064E FATHA       َ
  // U+064F DAMMA       ُ
  // U+0650 KASRA       ِ
  // U+0651 SHADDA      ّ
  // U+0652 SUKUN       ْ
  // U+0653 MADDAH      ٓ
  // U+0654 HAMZA ABOVE ٔ
  // U+0655 HAMZA BELOW ٕ
  // U+0656–U+065F additional marks
  // U+0670 SUPERSCRIPT ALEF  ٰ

  static final RegExp _diacriticsPattern = RegExp(
    '[\u064B-\u065F\u0670]',
  );

  // ── Alef Variants ──────────────────────────────────────────────────
  // أ U+0623 ALEF WITH HAMZA ABOVE
  // إ U+0625 ALEF WITH HAMZA BELOW
  // آ U+0622 ALEF WITH MADDA ABOVE
  // ٱ U+0671 ALEF WASLA

  static final RegExp _alefVariantsPattern = RegExp(
    '[\u0622\u0623\u0625\u0671]',
  );

  /// Normalizes Arabic text for search and comparison.
  ///
  /// This is the primary normalization method used by:
  /// - FTS5 indexing (data layer)
  /// - Search query preprocessing (presentation layer)
  /// - Contact name comparison (application layer)
  ///
  /// ## Example
  /// ```dart
  /// 'أَحْمَد'.normalizeArabic()  // → 'احمد'
  /// 'محمّدة'.normalizeArabic()   // → 'محمده'
  /// ```
  String normalizeArabic() {
    var result = this;

    // Step 1: Strip all diacritics (تشكيل)
    result = result.replaceAll(_diacriticsPattern, '');

    // Step 2: Normalize Alef variants → ا
    result = result.replaceAll(_alefVariantsPattern, '\u0627');

    // Step 3: Normalize Taa Marbuta → Haa (ة → ه)
    result = result.replaceAll('\u0629', '\u0647');

    // Step 4: Normalize Alef Maqsura → Yaa (ى → ي)
    result = result.replaceAll('\u0649', '\u064A');

    // Step 5: Trim and collapse whitespace
    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');

    return result;
  }

  /// Returns `true` if this string contains only Arabic characters,
  /// digits, spaces, and common punctuation.
  bool get isArabic => RegExp(r'^[\u0600-\u06FF\s\d\.\,\-]+$').hasMatch(this);

  /// Returns `true` if this string is empty or contains only whitespace.
  bool get isBlank => trim().isEmpty;

  /// Returns `true` if this string is not empty and not whitespace-only.
  bool get isNotBlank => !isBlank;
}
