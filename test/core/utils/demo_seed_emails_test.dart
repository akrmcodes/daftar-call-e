import 'dart:convert';
import 'dart:io';

import 'package:daftar/core/utils/demo_seed_emails.dart';
import 'package:daftar/core/utils/demo_seed_us_did.dart';
import 'package:daftar/core/utils/demo_store_seeder.dart';
import 'package:daftar/domain/constants/contact_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps seven contacts to plus-alias defaults', () {
    expect(DemoSeedEmails.tags, hasLength(DemoSeedEmails.contactCount));
    expect(
      DemoSeedEmails.tags.toSet(),
      hasLength(DemoSeedEmails.contactCount),
    );

    for (var i = 0; i < DemoSeedEmails.contactCount; i++) {
      final email = DemoSeedEmails.forIndex(i);
      expect(ContactEmail.isValid(email), isTrue, reason: 'index $i');
      expect(email, contains('+'), reason: 'index $i');
      expect(email, endsWith('@gmail.com'), reason: 'index $i');
    }

    expect(
      DemoSeedEmails.forIndex(0),
      'akrm.codes+demo1@gmail.com',
    );
    expect(
      DemoSeedEmails.forIndex(4),
      'qubati.akrm+demo5@gmail.com',
    );
  });

  test('Mohamed names resolve per locale', () {
    expect(
      DemoStoreSeeder.mohamedNameForLocale('en'),
      DemoStoreSeeder.mohamedNameEn,
    );
    expect(
      DemoStoreSeeder.mohamedNameForLocale('ar'),
      DemoStoreSeeder.mohamedNameAr,
    );
  });

  test('example overlay keys match dart-define tags', () {
    final raw = File('tool/demo_seed_emails.example.json').readAsStringSync();
    final map = json.decode(raw) as Map<String, dynamic>;
    expect(
      map.keys,
      unorderedEquals([
        DemoSeedUsDid.dartDefineKey,
        for (final tag in DemoSeedEmails.tags) 'DAFTAR_SEED_EMAIL_$tag',
      ]),
    );
    expect(map[DemoSeedUsDid.dartDefineKey], '');
    for (final tag in DemoSeedEmails.tags) {
      final value = map['DAFTAR_SEED_EMAIL_$tag'];
      expect(value, isA<String>());
      final email = value as String;
      expect(ContactEmail.isValid(email), isTrue);
      expect(email, endsWith('@gmail.com'));
    }
  });
}
