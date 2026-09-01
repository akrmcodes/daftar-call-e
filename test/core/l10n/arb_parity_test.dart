import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Arabic is the default locale, so a key that exists only in `app_en.arb`
/// ships as a missing getter, and a key only in `app_ar.arb` ships English
/// text to Arabic merchants. Both locales must stay in lockstep.
void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> ar;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  bool usesIcu(String value) =>
      value.contains(', plural,') || value.contains(', select,');

  /// Simple `{name}` substitutions only. ICU plural/select bodies are
  /// compared through [usesIcu] instead, since their branch text differs by
  /// design between locales.
  String placeholders(String value) {
    final names = RegExp(r'\{(\w+)\}')
        .allMatches(value)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort();
    return names.join(',');
  }

  /// Brand names and code formats are identical in every locale on purpose.
  const identicalByDesign = {
    'backupDriveSectionTitle',
    'activationCodeHint',
  };

  setUpAll(() {
    en = jsonDecode(File('lib/core/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    ar = jsonDecode(File('lib/core/l10n/app_ar.arb').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('every English key has an Arabic counterpart', () {
    expect(messageKeys(en).difference(messageKeys(ar)), isEmpty);
  });

  test('every Arabic key has an English counterpart', () {
    expect(messageKeys(ar).difference(messageKeys(en)), isEmpty);
  });

  test('placeholders match across locales', () {
    final mismatched = <String>[];
    for (final key in messageKeys(en).intersection(messageKeys(ar))) {
      final enValue = '${en[key]}';
      final arValue = '${ar[key]}';
      if (usesIcu(enValue) != usesIcu(arValue)) {
        mismatched.add(key);
        continue;
      }
      if (usesIcu(enValue)) {
        continue;
      }
      if (placeholders(enValue) != placeholders(arValue)) {
        mismatched.add(key);
      }
    }
    expect(mismatched, isEmpty);
  });

  test('no message is left empty in either locale', () {
    final empty = <String>[];
    for (final key in messageKeys(en)) {
      if ('${en[key]}'.trim().isEmpty || '${ar[key]}'.trim().isEmpty) {
        empty.add(key);
      }
    }
    expect(empty, isEmpty);
  });

  test('Arabic messages are not verbatim copies of the English source', () {
    // Catches keys added to app_ar.arb by copy-paste without translation.
    // Brand names and pure-placeholder strings are legitimately identical.
    final untranslated = <String>[];
    for (final key in messageKeys(en).intersection(messageKeys(ar))) {
      if (identicalByDesign.contains(key)) {
        continue;
      }
      final enValue = '${en[key]}'.trim();
      final arValue = '${ar[key]}'.trim();
      if (enValue.isEmpty || enValue != arValue) {
        continue;
      }
      final hasLatinLetters = RegExp('[a-zA-Z]{4,}').hasMatch(enValue);
      if (hasLatinLetters) {
        untranslated.add(key);
      }
    }
    expect(
      untranslated,
      isEmpty,
      reason: 'These keys ship English text to Arabic users',
    );
  });
}
