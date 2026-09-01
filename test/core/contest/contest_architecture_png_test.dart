import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('§7.1 architecture PNG in repo', () {
    test('PNG lives next to contest_architecture.md', () {
      final png = File('docs/architecture/contest_architecture.png');
      expect(png.existsSync(), isTrue);
      expect(png.lengthSync(), greaterThan(10 * 1024));
      expect(png.lengthSync(), lessThan(5 * 1024 * 1024));
    });

    test('markdown and README embed the PNG', () {
      final md = File('docs/architecture/contest_architecture.md').readAsStringSync();
      final readme = File('README.md').readAsStringSync();
      expect(md, contains('contest_architecture.png'));
      expect(readme, contains('docs/architecture/contest_architecture.png'));
    });

    test('repo root does not keep a duplicate PNG', () {
      expect(File('contest_architecture.png').existsSync(), isFalse);
    });
  });
}
