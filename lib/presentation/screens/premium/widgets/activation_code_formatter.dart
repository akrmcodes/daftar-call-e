import 'package:daftar/core/constants/app_constants.dart';
import 'package:flutter/services.dart';

/// Formats and normalizes premium activation codes for the vault seal field.
///
/// Display formats (LTR, auto-dashes every 4 body characters):
/// - Offline Pro+: `PROPLUS-XXXX-XXXX-XXXX-XXXX`
/// - Offline Pro: `PRO-XXXX-XXXX-XXXX`
/// - Generic online: `XXXX-XXXX-XXXX` (up to 16 alnum)
abstract final class ActivationCodeInput {
  /// Max alphanumeric characters for a generic (non-prefixed) online code.
  static const int maxGenericAlnum = 16;

  /// Normalizes a typed/pasted code for the offline validator / Edge activate.
  ///
  /// Preserves a single hyphen after `PRO` / `PROPLUS` prefixes. Strips other
  /// decorative dashes and whitespace.
  static String normalize(String input) {
    final raw = input.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('PROPLUS')) {
      final body = raw.substring(7);
      return '${AppConstants.offlineProPlusCodePrefix}$body';
    }

    if (raw.startsWith('PRO')) {
      final body = raw.substring(3);
      return '${AppConstants.offlineProCodePrefix}$body';
    }

    return _groupEvery4(raw);
  }

  /// Formats alphanumeric input for display while typing.
  static String format(String input) {
    final raw = input.trim().toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (raw.isEmpty) {
      return '';
    }

    // Incomplete PROPLUS prefix — show progressive letters (no early PRO- dash).
    if (raw.length < 7 && 'PROPLUS'.startsWith(raw)) {
      return raw;
    }

    if (raw.startsWith('PROPLUS')) {
      final body = _clip(raw.substring(7), AppConstants.offlineProPlusCodeLength - 8);
      return '${AppConstants.offlineProPlusCodePrefix}${_groupEvery4(body)}';
    }

    if (raw.startsWith('PRO')) {
      final body = _clip(raw.substring(3), AppConstants.offlineProCodeLength - 4);
      return '${AppConstants.offlineProCodePrefix}${_groupEvery4(body)}';
    }

    return _groupEvery4(_clip(raw, maxGenericAlnum));
  }

  static String _clip(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }

  static String _groupEvery4(String body) {
    if (body.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write('-');
      }
      buffer.write(body[i]);
    }
    return buffer.toString();
  }
}

/// Formats activation codes while typing (prefix-aware, dash every 4).
class ActivationCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = ActivationCodeInput.format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
