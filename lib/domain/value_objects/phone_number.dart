import 'package:equatable/equatable.dart';

/// Represents a phone number with validation and normalization capabilities.
///
/// Stores the raw input and provides methods for normalization (stripping
/// spaces, dashes, and standardizing country codes) and WhatsApp deep-link
/// generation.
///
/// ## Supported formats
/// - Yemeni: `+967 7XX XXX XXX`, `00967...`, `07XXXXXXXX`
/// - Saudi: `+966 5X XXX XXXX`, `00966...`, `05XXXXXXXX`
/// - Generic international: `+XXX ...`
///
/// ## Usage
/// ```dart
/// final phone = PhoneNumber('+967 777 123 456');
/// print(phone.normalized); // '967777123456' (digits only, WhatsApp)
/// print(phone.e164); // '+967771234567' (CALL-E phones[] when valid)
/// print(phone.whatsAppLink); // 'https://wa.me/967777123456'
/// ```
class PhoneNumber extends Equatable {
  /// Creates a [PhoneNumber] from a raw string.
  const PhoneNumber(this.raw);

  /// Supported Yemeni mobile operator prefixes (without country code).
  static const Set<String> yemeniOperatorPrefixes = {'71', '73', '77', '78'};

  /// ITU-T E.164 / CALL-E shape: `+` then 8–15 digits, first digit 1–9.
  static final RegExp _ituE164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

  /// The raw phone number string as entered by the user.
  final String raw;

  /// Returns the phone number stripped of all non-digit characters
  /// except for a leading `+` during intermediate parsing.
  ///
  /// Steps:
  /// 1. Trim whitespace
  /// 2. Remove common formatting characters (spaces, dashes, parentheses, dots)
  /// 3. Collapse repeated leading `00` international trunk prefixes
  /// 4. Strip any remaining non-digits
  /// 5. For Yemen numbers without country code, prepend `967`
  /// 6. For Saudi numbers without country code, prepend `966`
  /// 7. Return digits-only E.164-style output (no leading `+`)
  String get normalized {
    var phone = raw.trim();
    if (phone.isEmpty) return '';

    phone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    while (phone.startsWith('00') && phone.length > 2) {
      phone = '+${phone.substring(2)}';
    }

    if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }

    phone = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return '';

    phone = _collapseDuplicateCountryCode(phone);

    if (phone.startsWith('967') || phone.startsWith('966')) {
      return phone;
    }

    if (phone.startsWith('07') && phone.length == 10) {
      return '967${phone.substring(1)}';
    }
    if (phone.startsWith('7') && phone.length == 9) {
      return '967$phone';
    }
    if (phone.startsWith('05') && phone.length == 10) {
      return '966${phone.substring(1)}';
    }
    if (phone.startsWith('5') && phone.length == 9) {
      return '966$phone';
    }

    return phone;
  }

  /// Whether this phone number appears to be valid.
  ///
  /// A phone number is considered valid if, after normalization, it
  /// contains between 7 and 15 digits (per ITU-T E.164) and satisfies
  /// country-specific rules for Yemen and Saudi Arabia when detected.
  bool get isValid {
    final digits = normalized;
    if (digits.isEmpty) return false;

    if (!RegExp(r'^\d+$').hasMatch(digits)) return false;
    if (digits.length < 7 || digits.length > 15) return false;

    if (digits.startsWith('967')) {
      return _isValidYemeniMobile(digits);
    }
    if (digits.startsWith('966')) {
      return _isValidSaudiMobile(digits);
    }

    return true;
  }

  /// CALL-E `phones[]` form: `+` plus [normalized] digits.
  ///
  /// Returns `null` when [isValid] is false or the value does not match the
  /// ITU / CALL-E regex (`^\+[1-9]\d{7,14}$`). Use [normalized] for WhatsApp.
  String? get e164 {
    if (!isValid) return null;
    final formatted = '+$normalized';
    if (!_ituE164Pattern.hasMatch(formatted)) return null;
    return formatted;
  }

  static String _collapseDuplicateCountryCode(String digits) {
    const duplicateYemen = '^9670*967';
    const duplicateSaudi = '^9660*966';

    if (RegExp(duplicateYemen).hasMatch(digits)) {
      return digits.replaceFirst(RegExp(duplicateYemen), '967');
    }
    if (RegExp(duplicateSaudi).hasMatch(digits)) {
      return digits.replaceFirst(RegExp(duplicateSaudi), '966');
    }
    return digits;
  }

  static bool _isValidYemeniMobile(String digits) {
    if (digits.length != 12) return false;

    final operatorPrefix = digits.substring(3, 5);
    return yemeniOperatorPrefixes.contains(operatorPrefix);
  }

  static bool _isValidSaudiMobile(String digits) {
    if (digits.length != 12) return false;

    return digits[3] == '5';
  }

  /// Whether this phone number is empty or blank.
  bool get isEmpty => raw.trim().isEmpty;

  /// Whether this phone number is not empty.
  bool get isNotEmpty => !isEmpty;

  /// Returns a WhatsApp deep-link URL for this phone number.
  ///
  /// Uses `wa.me/{normalized}` format which opens the WhatsApp chat
  /// with the contact. Returns an empty string if the number is invalid.
  String get whatsAppLink {
    if (!isValid) return '';
    return 'https://wa.me/$normalized';
  }

  /// Returns a standard `tel:` URI for initiating a phone call.
  ///
  /// Returns an empty string if the number is invalid.
  String get telLink {
    if (!isValid) return '';
    return 'tel:+$normalized';
  }

  /// Returns the detected country code, or `null` if unknown.
  ///
  /// Currently recognizes:
  /// - `967` (Yemen)
  /// - `966` (Saudi Arabia)
  /// - `20` (Egypt)
  String? get countryCode {
    final digits = normalized;
    if (digits.startsWith('967')) return '967';
    if (digits.startsWith('966')) return '966';
    if (digits.startsWith('20')) return '20';
    return null;
  }

  @override
  List<Object?> get props => [normalized];

  @override
  String toString() => 'PhoneNumber($raw)';
}
