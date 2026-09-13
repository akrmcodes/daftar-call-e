import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _mermaidBlocks(String markdown) {
  return RegExp(r'```mermaid\r?\n([\s\S]*?)```')
      .allMatches(markdown)
      .map((m) => m.group(1)!)
      .join('\n');
}

void main() {
  late String md;
  late String readme;
  late String mermaid;

  setUpAll(() {
    md = File('docs/architecture/contest_architecture.md').readAsStringSync();
    readme = File('README.md').readAsStringSync();
    mermaid = _mermaidBlocks(md);
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

    test('system mermaid is CALL-E sibling create/get plus dual rail', () {
      expect(mermaid, contains('CALL-E Developer API'));
      expect(mermaid, contains('plan-batch'));
      expect(mermaid, contains('run-batch'));
      expect(mermaid, contains('send-batch'));
      expect(mermaid, contains('Validate plan-batch'));
      expect(mermaid, contains('Create calls.create'));
      expect(mermaid, contains('Poll GET'));
    });

    test('mermaid does not render the Agentic planner plane', () {
      expect(mermaid, isNot(contains('POST /run')));
      expect(mermaid, isNot(contains('ADK 8 tools')));
      expect(mermaid, isNot(contains('Vertex')));
      expect(
        mermaid,
        isNot(contains('subgraph cloud [Cloud Run daftar-closing-agent]')),
      );
    });

    test('does not frame this submission as Agentic Taskmaster judging', () {
      final lowered = md.toLowerCase();
      expect(md, isNot(contains('**Track:** Taskmaster')));
      expect(lowered, isNot(contains('architectural discipline (30%)')));
      expect(lowered, isNot(contains('best architectural design')));
    });
  });
}
