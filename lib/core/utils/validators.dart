import 'package:daftar/core/utils/money_util.dart';

/// Pure input validation functions for form fields.
///
/// Each validator returns `null` for valid input or an error message
/// string for invalid input. These are designed for use with Flutter's
/// `TextFormField.validator` callback.
///
/// Validators are stateless and side-effect-free — they belong in the
/// core layer and can be used by both presentation (form validation)
/// and application (use case precondition checks) layers.
abstract final class Validators {
  /// Maximum allowed length for names (contacts, ledgers).
  static const int maxNameLength = 100;

  /// Maximum allowed length for notes/description fields.
  static const int maxNotesLength = 500;

  /// Validates a name field (contact name, ledger name).
  ///
  /// Returns `null` if valid, or an error message string.
  /// - Must not be empty or whitespace-only.
  /// - Must not exceed [maxNameLength] characters.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الاسم مطلوب'; // Name is required
    }
    if (value.trim().length > maxNameLength) {
      return 'الاسم طويل جداً'; // Name is too long
    }
    return null;
  }

  /// Validates a monetary amount input string for [currencyCode].
  ///
  /// Returns `null` if valid, or an error message string.
  /// Parsing uses integer minor-unit conversion — never [double].
  static String? validateAmount(String? value, {String currencyCode = 'YER'}) {
    if (value == null || value.trim().isEmpty) {
      return 'المبلغ مطلوب'; // Amount is required
    }
    final parsed = MoneyUtil.parseMinorUnitsForCode(value.trim(), currencyCode);
    if (parsed == null) {
      return 'مبلغ غير صالح'; // Invalid amount
    }
    if (parsed <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر'; // Amount must be > 0
    }
    return null;
  }

  /// Validates an optional phone number.
  ///
  /// Returns `null` if valid (or empty — phone is optional).
  /// Only validates if a value is provided.
  /// - Must contain only digits, spaces, dashes, plus, and parentheses.
  /// - Must be at least 7 digits long.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }

    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.length < 7) {
      return 'رقم الهاتف قصير جداً'; // Phone number too short
    }
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'رقم هاتف غير صالح'; // Invalid phone number
    }
    return null;
  }

  /// Validates an ISO 4217 currency code.
  ///
  /// Returns `null` if valid, or an error message string.
  /// - Must be exactly 3 uppercase letters.
  static String? validateCurrencyCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رمز العملة مطلوب'; // Currency code is required
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(value.trim())) {
      return 'رمز العملة يجب أن يكون 3 أحرف كبيرة'; // Must be 3 uppercase
    }
    return null;
  }

  /// Validates a notes/description field.
  ///
  /// Returns `null` if valid (or empty — notes are optional).
  /// - Must not exceed [maxNotesLength] characters.
  static String? validateNotes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Notes are optional
    }
    if (value.trim().length > maxNotesLength) {
      return 'الملاحظات طويلة جداً'; // Notes too long
    }
    return null;
  }
}
