import 'package:daftar/domain/constants/contact_email.dart';

/// Compile-time contest seed emails for the seven desk-eligible sample contacts.
///
/// Defaults route to owner plus-aliases for Gate 4 inbox proof. Forks may override
/// via `--dart-define-from-file=tool/demo_seed_emails.local.json`. Never log
/// resolved addresses.
abstract final class DemoSeedEmails {
  /// Seven sample debtors — index order matches `DemoStoreSeeder` contact list.
  static const int contactCount = 7;

  /// `DAFTAR_SEED_EMAIL_<tag>` suffixes (`demo1` … `demo7`).
  static const List<String> tags = [
    'demo1',
    'demo2',
    'demo3',
    'demo4',
    'demo5',
    'demo6',
    'demo7',
  ];

  static const String _defaultDemo1 = 'akrm.codes+demo1@gmail.com';
  static const String _defaultDemo2 = 'akrm.codes+demo2@gmail.com';
  static const String _defaultDemo3 = 'akrm.codes+demo3@gmail.com';
  static const String _defaultDemo4 = 'akrm.codes+demo4@gmail.com';
  static const String _defaultDemo5 = 'qubati.akrm+demo5@gmail.com';
  static const String _defaultDemo6 = 'qubati.akrm+demo6@gmail.com';
  static const String _defaultDemo7 = 'qubati.akrm+demo7@gmail.com';

  static const String _demo1 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo1',
    defaultValue: _defaultDemo1,
  );
  static const String _demo2 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo2',
    defaultValue: _defaultDemo2,
  );
  static const String _demo3 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo3',
    defaultValue: _defaultDemo3,
  );
  static const String _demo4 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo4',
    defaultValue: _defaultDemo4,
  );
  static const String _demo5 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo5',
    defaultValue: _defaultDemo5,
  );
  static const String _demo6 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo6',
    defaultValue: _defaultDemo6,
  );
  static const String _demo7 = String.fromEnvironment(
    'DAFTAR_SEED_EMAIL_demo7',
    defaultValue: _defaultDemo7,
  );

  /// Seeded SMTP address for contact index `0` … `6`.
  static String forIndex(int index) {
    if (index < 0 || index >= contactCount) {
      throw RangeError.range(index, 0, contactCount - 1, 'index');
    }
    return switch (index) {
      0 => _pick(_demo1, _defaultDemo1),
      1 => _pick(_demo2, _defaultDemo2),
      2 => _pick(_demo3, _defaultDemo3),
      3 => _pick(_demo4, _defaultDemo4),
      4 => _pick(_demo5, _defaultDemo5),
      5 => _pick(_demo6, _defaultDemo6),
      6 => _pick(_demo7, _defaultDemo7),
      _ => _defaultDemo1,
    };
  }

  static String _pick(String compiled, String fallback) {
    final normalized = ContactEmail.normalize(compiled);
    if (normalized == null || !ContactEmail.isValid(normalized)) {
      return fallback;
    }
    return normalized;
  }
}
