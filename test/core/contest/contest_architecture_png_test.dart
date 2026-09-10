import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String md;
  late String readme;

  setUpAll(() {
    md = File('docs/architecture/contest_architecture.md').readAsStringSync();
    readme = File('README.md').readAsStringSync();
  });

  group('§7.1 architecture PNG in repo', () {
    test('PNG lives next to contest_architecture.md', () {
      final png = File('docs/architecture/contest_architecture.png');
      expect(png.existsSync(), isTrue);
      expect(png.lengthSync(), greaterThan(10 * 1024));
      expect(png.lengthSync(), lessThan(5 * 1024 * 1024));
    });

    test('markdown and README embed the PNG', () {
      expect(md, contains('contest_architecture.png'));
      expect(readme, contains('docs/architecture/contest_architecture.png'));
    });

    test('repo root does not keep a duplicate PNG', () {
      expect(File('contest_architecture.png').existsSync(), isFalse);
    });
  });

  group('§6.1 CALL-E architecture copy', () {
    test('names daftar-call-e and the locked captions', () {
      expect(md, contains('daftar-call-e'));
      expect(md.toLowerCase(), contains('not an adk tool'));
      expect(md, contains('Developer API'));
      expect(md, contains('Validate'));
      expect(md, contains('Create'));
      expect(md, contains('Poll'));
    });

    test('runtime mermaid is daftar-call-e not the frozen Agentic service', () {
      expect(md, contains('subgraph cloud [Cloud Run daftar-call-e]'));
      expect(md, isNot(contains('subgraph cloud [Cloud Run daftar-closing-agent]')));
    });

    test('does not frame this submission as Agentic Taskmaster judging', () {
      final lowered = md.toLowerCase();
      expect(md, isNot(contains('**Track:** Taskmaster')));
      expect(lowered, isNot(contains('architectural discipline (30%)')));
      expect(lowered, isNot(contains('best architectural design')));
    });
  });
}
