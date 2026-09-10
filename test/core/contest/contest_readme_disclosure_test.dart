import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String readme;
  late String docsIndex;

  setUpAll(() {
    readme = File('README.md').readAsStringSync();
    docsIndex = File('docs/README.md').readAsStringSync();
  });

  group('§6.2 root README CALL-E packaging', () {
    test('names CALL-E hackathon, runtime, and dual rail', () {
      expect(readme, contains('call-e.devpost.com'));
      expect(readme, contains('daftar-call-e'));
      expect(readme, contains('Confirm & Call'));
      expect(readme, contains('task_completed'));
      expect(readme, contains('Singapore'));
      expect(readme, contains('Callcentric'));
      expect(readme, contains('Linphone'));
    });

    test('binds v3.5 and marks v2.8 heritage', () {
      expect(readme, contains('roadmap_v3'));
      expect(readme, contains('v3.5'));
      expect(readme, contains('v2.8'));
    });

    test('does not frame this submission as Agentic Taskmaster judging', () {
      final lowered = readme.toLowerCase();
      expect(readme, isNot(contains('**Track:** Taskmaster')));
      expect(lowered, isNot(contains('architectural discipline (30%)')));
      expect(lowered, isNot(contains('best architectural design')));
    });

    test('runtime service is daftar-call-e not the frozen Agentic hostname', () {
      expect(readme, contains('daftar-call-e-1487285471.us-central1.run.app'));
      expect(
        readme,
        isNot(contains('https://daftar-closing-agent-1487285471.us-central1.run.app')),
      );
    });

    test('embeds the architecture PNG and has no live E.164', () {
      expect(readme, contains('docs/architecture/contest_architecture.png'));
      expect(RegExp(r'\+1\d{10}').hasMatch(readme), isFalse);
    });
  });

  group('§6.2 docs index judge order', () {
    test('opens on CALL-E not Taskmaster', () {
      expect(docsIndex, contains('call-e.devpost.com'));
      expect(docsIndex, contains('v3.5'));
      expect(docsIndex, isNot(contains('**Track:** Taskmaster')));
      expect(docsIndex.toLowerCase(), isNot(contains('17:00 pdt')));
    });
  });
}
