import 'package:daftar/core/errors/failures.dart';
import 'package:daftar/core/l10n/generated/app_localizations.dart';
import 'package:daftar/core/utils/error_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorTranslator rate limit', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('uses retry message when retryAfterSeconds is present', () {
      const failure = RateLimitedFailure(
        'Rate limited',
        retryAfterSeconds: 3600,
      );

      final content = ErrorTranslator.translate(l10n, failure);

      expect(content.title, l10n.errorRateLimitedTitle);
      expect(content.message, contains('60'));
      expect(content.message, isNot(contains('upgrade')));
    });

    test('uses generic retry message without retry hint', () {
      const failure = RateLimitedFailure('Rate limited');

      final content = ErrorTranslator.translate(l10n, failure);

      expect(content.title, l10n.errorRateLimitedTitle);
      expect(content.message, l10n.errorRateLimitedMessage);
    });
  });
}
