import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter lib/ has no Gmail SMTP secret filenames', () {
    const needles = [
      'GMAIL_SMTP_PASSWORD',
      'smtp-app-password',
      'gmail-smtp-app-password',
    ];
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final text = entity.readAsStringSync();
      for (final needle in needles) {
        if (text.contains(needle)) {
          hits.add('${entity.path}: $needle');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
