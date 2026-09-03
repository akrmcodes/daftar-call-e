import 'package:daftar/domain/constants/j10_calle_regions.dart';
import 'package:daftar/domain/value_objects/phone_number.dart';

/// Compile-time owner US DID for the call-eligible sample contact (Mohamed).
///
/// Override via `--dart-define-from-file=tool/demo_seed_emails.local.json`.
/// Not Envied — never log resolved values.
abstract final class DemoSeedUsDid {
  /// Dart-define key for the owner inbound US DID (NANP E.164).
  static const String dartDefineKey = 'DAFTAR_SEED_US_DID';

  static const String _compiled = String.fromEnvironment(dartDefineKey);

  /// Valid Yemen Mobile placeholder for sample contact index `0` … `6`.
  ///
  /// Uses operator prefix `77` so [PhoneNumber.isValid] and J.10 YE gate apply.
  static String yemenPlaceholder(int index) {
    if (index < 0 || index >= 7) {
      throw RangeError.range(index, 0, 6, 'index');
    }
    return '+96777123456$index';
  }

  /// Owner US DID when [override] or compile-time define is a valid NANP E.164.
  ///
  /// Returns `null` when unset, empty, invalid, or non-NANP (e.g. YE / SA).
  static String? resolve({String? override}) {
    final raw = (override ?? _compiled).trim();
    if (raw.isEmpty) {
      return null;
    }

    final phone = PhoneNumber(raw);
    final e164 = phone.e164;
    if (e164 == null) {
      return null;
    }

    if (J10CalleRegions.callingRegion(e164) != J10CalleRegions.nanp) {
      return null;
    }

    return e164;
  }
}
