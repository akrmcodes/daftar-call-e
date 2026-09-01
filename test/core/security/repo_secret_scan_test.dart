import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firebase client config is public by design (not a credential).
const _firebaseClientAllowlist = {
  'android/app/google-services.json',
  'ios/Runner/GoogleService-Info.plist',
  'lib/firebase_options.dart',
};

const _binaryExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.ico',
  '.woff',
  '.woff2',
  '.ttf',
  '.otf',
  '.so',
  '.dylib',
  '.a',
  '.jar',
  '.aar',
  '.zip',
  '.gz',
  '.pdf',
  '.mp4',
  '.webm',
  '.apk',
  '.jks',
  '.keystore',
  '.p12',
  '.der',
  '.lock',
};

final _contentPatterns = <(String, RegExp)>[
  (
    'PEM private key',
    RegExp('-----BEGIN (?:RSA |OPENSSH |EC |DSA |OPENSSH )?PRIVATE KEY-----'),
  ),
  (
    'GCP service-account JSON',
    RegExp(r'''["']type["']\s*:\s*["']service_account["']'''),
  ),
  ('GitHub PAT (ghp_)', RegExp('ghp_[A-Za-z0-9]{36}')),
  ('GitHub PAT (github_pat_)', RegExp('github_pat_[A-Za-z0-9_]{20,}')),
  ('Gmail SMTP password assignment', RegExp(r'GMAIL_SMTP_PASSWORD\s*=')),
  ('AWS access key', RegExp('AKIA[0-9A-Z]{16}')),
];

void main() {
  late List<String> tracked;

  setUpAll(() async {
    final result = await Process.run(
      'git',
      ['ls-files', '-z'],
      workingDirectory: Directory.current.path,
    );
    expect(result.exitCode, 0, reason: result.stderr.toString());
    tracked = (result.stdout as String)
        .split('\x00')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  });

  test('git does not track credential or sideload binary paths', () {
    final hits = <String>[];
    for (final path in tracked) {
      final base = path.split('/').last;
      final lower = path.toLowerCase();
      if (base == '.env' ||
          base.endsWith('.env') ||
          base.startsWith('.env.') ||
          base.contains('client_secret') ||
          lower.endsWith('.apk') ||
          lower.endsWith('.jks') ||
          lower.endsWith('.keystore') ||
          lower.endsWith('.p12') ||
          lower.endsWith('.pem')) {
        hits.add(path);
      }
    }
    expect(hits, isEmpty, reason: 'tracked secret-like paths: $hits');
  });

  test('tracked text has no PEM, service-account JSON, tokens, or SMTP password',
      () {
    final hits = <String>[];
    for (final path in tracked) {
      if (_firebaseClientAllowlist.contains(path)) {
        continue;
      }
      final lower = path.toLowerCase();
      if (_binaryExtensions.any(lower.endsWith)) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      final bytes = file.readAsBytesSync();
      if (bytes.length > 2 * 1024 * 1024) {
        continue;
      }
      late final String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        continue;
      }
      for (final (label, pattern) in _contentPatterns) {
        if (pattern.hasMatch(text)) {
          hits.add('$path ($label)');
        }
      }
    }
    expect(hits, isEmpty, reason: 'secret-pattern hits: $hits');
  });

  test('README does not publish the live Pro+ activation code', () {
    final readme = File('README.md').readAsStringSync();
    expect(readme.contains('PROPLUS-QM9VUV9VLH8ZC529'), isFalse);
  });
}
