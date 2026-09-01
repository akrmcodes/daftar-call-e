/// Optional contact email for Collections SMTP (Appendix C.2 / J.7).
abstract final class ContactEmail {
  static final RegExp _pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Trims; empty becomes null. Does not validate.
  static String? normalize(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  /// Plus-aliases allowed. Empty/null is valid (optional field).
  static bool isValid(String? raw) {
    final normalized = normalize(raw);
    if (normalized == null) {
      return true;
    }
    return _pattern.hasMatch(normalized);
  }
}
